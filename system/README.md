# Australis system userland

System userland owns startup order, service supervision, mount and device
policy, session creation, and application launch policy. It uses the same
checked process boundary as other AUEX programs. The kernel keeps hardware,
VFS, scheduling, system calls, and the KMon recovery path. See the
[architecture](../../README.md) and [userland stages](../README.md).

## First boot contract

```text
BOOTX64.EFI -> KERNEL.BIN -> /System/Core/System.exec (PID 1)
                                      -> CommandShell.exec
                                      -> optional graphical session
```

The kernel starts `System.exec` only after mounting and validating the
read-only HyFS 2 root. Initially it is a direct `.exec` payload at
`/System/Core/System.exec`. `System.os` describes a later bundle for the
same component; the extension does not grant privilege. The first normal
session is text-only. GUI startup is optional and comes after service, IPC,
and session contracts are in place.

## Current status and next gates

The image builder creates `/System/Core`, but it does not yet install
`System.exec`. There is no PID 1 process table, service supervisor, or
session manager. The kernel recovery shell remains the boot console.

1. Userland Stage 2 moves ordinary commands into independent `.exec`
   programs and establishes `CommandShell.exec`.
2. Stage 3 packages the system tree and verifies missing, invalid, and
   corrupt system images still enter KMon.
3. Stage 4 adds multiple runnable processes, blocking waits, PID 1,
   bounded service restart, and a text session.
4. Stages 5 and 6 add versioned IPC/capabilities, sessions, and optional
   graphical services.

The first services are Device, Storage, and Launch policy. Drivers stay in
the kernel until a capability and IPC model can isolate them. `rescue.exec`
may offer disk-backed tools, but KMon must work without the root volume.

## Exit test

PID 1 starts `CommandShell.exec` on AHCI and NVMe, restarts one deliberately
failed service only to its configured limit, records the cause, and releases
all resources after exit. An explicit recovery boot or failed PID 1 reaches
KMon. No service runs inside an interrupt handler.
