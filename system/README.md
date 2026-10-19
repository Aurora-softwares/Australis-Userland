# Australis system userland

System userland owns startup order, service supervision, mount and device
policy, session creation, and application launch policy. It uses the same
checked process boundary as other AUEX programs. The kernel keeps hardware,
VFS, scheduling, system calls, and the KMon recovery path. See the
[architecture](../../README.md) and [userland stages](../README.md).

## First boot contract

```text
BOOTX64.EFI -> KERNEL.BIN -> /System/Core/System.exec (PID 1)
                                      -> Device.exec -> Storage.exec
                                      -> Display.exec (optional, persistent)
                                           -> DisplayDemoA.exec
                                           -> DisplayDemoB.exec
                                      -> CommandShell.exec (serial)
```

The kernel starts `System.exec` only after mounting and validating the
read-only HyFS 2 root. Initially it is a direct `.exec` payload at
`/System/Core/System.exec`. `System.os` describes a later bundle for the
same component; the extension does not grant privilege. The first normal
session retains the serial shell. The optional display service draws beside
that session when the checked GOP mode is supported. A window click routes
USB keyboard input to that window's client; a wallpaper click returns it to
the shell. COM1 shell input stays active throughout.

## Current status and next gates

The image builder installs `System.exec`, `Device.exec`, `Storage.exec`,
`Display.exec`, its two demonstration clients, and `CommandShell.exec` under
`/System/Core`, plus the versioned
`/System/Config/startup.manifest` and
`/System/Config/capabilities.manifest`. PID 1 starts the two one-shot readiness
checks in manifest order, then tries to start the display service and the
command shell. Display failure does not block the serial shell. An explicit rescue or debug
boot enters KMon; a missing or failed system image falls back to KMon.
The shell parses commands and arguments, maintains a working directory and
exported environment, and launches foreground `/System/Bin` executables.
PID 1 waits for one-shot services to report readiness and exit. It keeps the
display service alive while the shell runs, then terminates and reaps it.
The manifest sets each readiness bound and retry count. The command shell has
three attempts; a clean exit ends the session without a retry.

The `AUSM1` file contains one `name|absolute path|attempts|ready rounds|mode`
record per line. `O` runs a one-shot check and advances only after readiness
and exit code 0; `S` starts the final interactive session. PID 1 accepts at
most four records and requires `S` to be last. A readiness timeout terminates
and reaps that child before the next attempt.
Packaged system files and KMon fallback for missing or malformed PID 1 and
corrupt HyFS metadata are covered by `make test-userland-stage3`.
The AUEX runtime schedules live children in bounded instruction quanta and
supports spawn, wait, readiness, termination, and timer-backed sleep. AUN1
children use timer-preempted slices and can accept invited channels.
General persistent-service supervision and a session manager remain.

The `AUSC1` capability file contains `absolute path|mask` records. Bit `1`
grants channel creation to a direct child. Missing, malformed, or unmatched
records grant nothing. The kernel reads this file from the read-only root and
checks the grant against the caller's process record on channel open. Bit `2`
allows one process to claim the exclusive display lease. `Display.exec` has
mask `3`; its clients have no display capability.

1. Stage 2 child context, launch errors, terminal parity, and repeated
   read-only command cleanup pass on AHCI and NVMe. Precise release after
   filesystem mutation remains future kernel memory work.
2. Stage 3 packages the system tree and verifies missing, invalid, and
   corrupt system images still enter KMon on AHCI and NVMe.
3. Stage 4 has live AUEX child scheduling and manifest-driven startup with
   bounded readiness and retries; persistent service supervision remains.
4. Stage 5 exposes versioned channel calls to AUEX programs and AUN1 children
   with checked peer identity, a declared channel grant, and exit cleanup.
   Shared buffers and other capability types remain. Stage 6 adds sessions
   and optional graphical services.

The first services are Device, Storage, and Launch policy. Drivers stay in
the kernel until a capability and IPC model can isolate them. `rescue.exec`
may offer disk-backed tools, but KMon must work without the root volume.

## Exit test

PID 1 starts `CommandShell.exec` on AHCI and NVMe, restarts one deliberately
failed service only to its configured limit, records the cause, and releases
all resources after exit. An explicit recovery boot or failed PID 1 reaches
KMon. No service runs inside an interrupt handler.

`make test-userland-stage4-supervision` checks bounded shell retries and KMon
fallback on AHCI and NVMe. `make test-userland-stage4-concurrency` checks two
overlapping AUEX children, readiness, and wait behavior on both transports.
