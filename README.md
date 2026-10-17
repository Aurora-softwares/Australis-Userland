# Australis userland plan

This directory is the planned home of operating-system programs that execute
above the kernel. The GUI is one userland subsystem. Command-line tools,
services, login, sessions, and the desktop all use the same process boundary.

KMon remains the kernel recovery console. The normal userland shell boots
through `System.exec` and launches foreground commands from `/System/Bin`.

## Boundary with the kernel

The kernel should expose small, versioned mechanisms:

- process creation, arguments, waiting, termination, and scheduling;
- user memory, descriptors, system calls, and fault containment;
- files, directories, mounts, devices, clocks, and system information;
- IPC endpoints, events, capabilities, and shared buffers;
- framebuffer, input, storage, and network driver interfaces.

Userland should implement policy:

- system and service startup order;
- service restart and failure reporting;
- environment variables and executable search;
- mount, device, network, login, and session policy;
- application manifests and capability requests;
- display composition, windows, desktop behavior, and notifications.

## CLI Commands to require

### Essentials

`🟢` means implemented in the intended userland location and callable from
`CommandShell.exec`: 🟢 complete, `🟡` partial, 🔴 missing. Mutating commands
must target a writable volume such as `/data`; the boot root is read-only.

| | Command | Owner | Current state |
| --- | --- | --- | --- |
| 🟢 | `help` | Shell built-in | Lists built-ins and installed `/System/Bin` executables. |
| 🟢 | `cd` | Shell built-in | Changes shell-owned working-directory state and normalizes relative paths. |
| 🟢 | `ls` | `/System/Bin/ls.exec` | Lists files and directories through the checked directory API. |
| 🟢 | `pwd` | Shell built-in | Prints the shell's current directory. |
| 🟢 | `cat` | `/System/Bin/cat.exec` | Streams file contents through the checked file API. |
| 🟢 | `echo` | `/System/Bin/echo.exec` | Prints parsed command arguments. |
| 🟢 | `clear` | `/System/Bin/clear.exec` | Clears serial and framebuffer terminals through the terminal API. |
| 🟢 | `exit` | Shell built-in | Ends the current session and returns to KMon. |
| 🟢 | `history` | Shell built-in | Shows the last eight nonempty input lines. |
| 🟢 | `tree` | `/System/Bin/tree.exec` | Traverses directories iteratively up to the filesystem's path limit. |
| 🟢 | `mkdir` | `/System/Bin/mkdir.exec` | Creates a directory on a writable volume. |
| 🟢 | `touch` | `/System/Bin/touch.exec` | Creates an empty file if absent; timestamp updating is not exposed. |
| 🟢 | `cp` | `/System/Bin/cp.exec` | Copies file data in chunks with checked descriptors; removes an incomplete destination if it created one. |
| 🟢 | `mv` | `/System/Bin/mv.exec` | Renames within a volume; cross-volume moves copy then delete when writable. |
| 🟢 | `rm` | `/System/Bin/rm.exec` | Removes files and empty directories. |

### File utilities

| | Command | Purpose |
| --- | --- | --- |
| 🟢 | **`edit`** | Terminal text editor with cursor navigation, Save and Save As; opens any file as text, with a 4096-byte buffer |
| 🔴 | **`view`** | Paged read-only text viewer; `cat` already covers simple file display |
| 🟢 | **`hexedit`** | Terminal hex and ASCII editor with byte navigation, Save and Save As, and a 4096-byte buffer |
| 🔴 | **`hexview`** | Hexadecimal file viewer |
| 🟢 | **`inspector`** | Detailed filesystem metadata and recognized AUEX header fields; this covers the proposed `finfo` role |

### System administration

The same rule applies here. KMon recovery commands do not count as
normal userland administration commands.

| | Command | Owner | Current state |
| --- | --- | --- | --- |
| 🟢 | `sys-info` | `/System/Bin/sys-info.exec` | Read-only system summary launches from the userland shell. |
| 🔴 | `uptime` | `/System/Bin/uptime.exec` | No elapsed-time user API or command yet. |
| 🟢 | `mem-info` | `/System/Bin/mem-info.exec` | Read-only memory and allocator summary launches from the shell. |
| 🟡 | `ps` | `/System/Bin/ps.exec` | Shows the foreground process and last launch, not a full process table. |
| 🔴 | `kill` | `/System/Bin/kill.exec` | Needs independent processes and a checked termination API. |
| 🔴 | `top` | `/System/Bin/top.exec` | Needs process accounting and periodic terminal updates. |
| 🟡 | `devices` | `/System/Bin/devices.exec` | KMon has a recovery view; no userland command/API yet. |
| 🟡 | `drivers` | `/System/Bin/drivers.exec` | Reports active driver categories, not an installed-driver inventory. |
| 🔴 | `services` | `/System/Bin/services.exec` | Needs the service manager and control API. |
| 🔴 | `mount` | `/System/Bin/mount.exec` | Needs privileged mount policy and a checked API. |
| 🔴 | `umount` | `/System/Bin/umount.exec` | Needs privileged unmount policy and a checked API. |
| 🔴 | `df` | `/System/Bin/df.exec` | Needs filesystem capacity and free-space queries. |
| 🔴 | `dmesg` | `/System/Bin/dmesg.exec` | Needs a retained, readable kernel log. |
| 🟡 | `reboot` | `/System/Bin/reboot.exec` | KMon can reboot; userland has no authorized reboot API. |
| 🟡 | `shutdown` | `/System/Bin/shutdown.exec` | KMon can halt; userland has no authorized shutdown API. |

## Stage 1: process inputs and application runtime

### Kernel and AUEX

- 🟢 Define a versioned process-start record containing `argc`, `argv`,
  environment entries, working directory, and standard descriptors.
- 🟢 Copy all start data through checked user memory and reject malformed counts,
  lengths, pointers, and duplicate ownership.
- 🟢 Add syscall results with explicit success, end-of-file, retry, invalid
  argument, not found, permission, and I/O error states.
- 🟢 Add dynamic-path open calls and read-only system-information queries.
- 🟢 Add process identifiers plus foreground `spawn`, `wait`, and exit status.

### Compiler

- 🟢 Populate `Main(string[] args)` for `type = "exec"` projects in the
  recovery shell, with bounded argument count, indexing, comparison, length,
  and output.
- 🟢 Add scalar locals, integer and Boolean operations, comparisons,
  branches, loops, `break`, `continue`, and computed console output and exits
  to the AUEX backend.
- 🟢 Add application method calls to the AUEX backend.
- 🟢 Add bounded strings and byte arrays backed by the user data region.
- 🟢 Preserve the existing AUEX validation, CRC, instruction limit, and cleanup
  behavior.

### Exit test

An argument-printing `.exec` receives multiple edited arguments, returns a
nonzero status, and leaves descriptor and page counts unchanged after repeated
AHCI and NVMe QEMU runs. Run `make test-userland-stage1` to rebuild the hosted
runtime, compile the fixture, and check both boot paths.

The `AUSP` version 1 start record is copied to read-only user memory at
`0x600000`. Its header stores the record length, argument and environment
counts, working-directory pointer and length, and standard descriptors. Up to
16 arguments and 16 environment entries use checked pointer/length tables;
each string is NUL terminated. The default directory is `/`, and the standard
descriptors are 0, 1, and 2. The caller's buffers are copied before execution.
The stage 1 argument fixture lives in `tests/user`.
Native AUN1 children receive `AUSP` version 2 in their data page; its
argument, environment, and directory references are 64-bit offsets from the
startup record rather than the AUEX v1 checked pointers.
`System.exec` in this directory is the PID 1 entry point. It reads the
versioned startup manifest, launches ordered Device and Storage checks, then
supervises `CommandShell.exec`. Persistent service management remains later
work.

## Stage 2: external command shell

`CommandShell.exec` is built from `src/shell` and packaged at
`/System/Core/CommandShell.exec`. Normal boot starts it through `System.exec`.
It parses quoted and escaped input, keeps a working directory and eight-entry
history, resolves ordinary commands through an editable `PATH` (default
`/System/Bin`), and passes bounded arguments
to a foreground child. It retains `run` for an explicit executable path.

The first external command, `cat.exec`, is source-built from
`commands/Cat/Cat.hyproj` and installed at `/System/Bin/cat.exec` in the normal HyFS 2
image. The current KMon shell resolves bare `cat /hello.txt` through `PATH`.
`make test-userland-cat` checks multi-chunk
output, empty-file EOF, a missing-path error, and resource cleanup on AHCI and
NVMe.

`sys-info.exec` and `mem-info.exec` are also source-built applications in the
OS aggregate. They use the read-only selectors introduced in
system-information API version 2 to replace the former
`cpu`, `cpuid`, `timer`, and `heap` command proposals with read-only summaries.
They do not expose raw kernel addresses or writable diagnostic operations.

`ls.exec` lists a directory or a named file with the checked file API.
`ps.exec` reports the currently running foreground program and the result of
the previous launch through system-information API version 3. Bare `ls` and
`ps` now resolve these programs through `PATH`; KMon retains `mounts` for
early recovery. The AUEX host can schedule multiple runnable children, while
`ps.exec` still shows only the foreground program and previous launch.

`drivers.exec` uses system-information API version 4 to report active serial,
storage, USB, and timer drivers. `mem.exec` reports available pages and kernel
heap usage. KMon provides `devices`, `memmap`, and `pages` without a userland
process; detailed physical ranges from `memmap` require `D` Debug boot.

- `echo.exec`, `tree.exec`, `mkdir.exec`, `touch.exec`, `cp.exec`, `mv.exec`,
  and `rm.exec` are separate source projects; `clear.exec` uses a checked
  terminal clear operation. `cd`, `pwd`, `history`, `help`, and `exit` are
  shell built-ins because they work with shell-owned session state.
- `path` displays or changes the shell's session-local, colon-separated search
  path. The kernel recovery shell retains its own search path.
- `set`, `export`, and `unset` manage bounded shell variables; exported entries
  and `PATH` are copied into each child's start record alongside the current
  working directory.
- Keep explicit `run /path/program.exec` during the transition.
- Missing images, malformed images, and denied launches have distinct shell
  messages. Nonzero exits and program faults return to the prompt; terminal
  end-of-input ends the text session cleanly.

### Stage 2 completion checklist

This checklist is for **userland Stage 2**, not the bootloader's second stage.
`🟢` means implemented and exercised, `🟡` means partly implemented, and
`🔴` means still required for the Stage 2 exit test.

- 🟢 Boot `System.exec` as PID 1 and enter `CommandShell.exec` on a normal
  AHCI or NVMe boot; keep KMon reachable after shell exit or startup failure.
- 🟢 Parse bounded quoted/escaped arguments, launch and wait for foreground
  `/System/Bin/*.exec` programs, and return to the prompt after nonzero exits
  and program faults.
- 🟢 Provide `cd`, `pwd`, `history`, `help`, `exit`, and an editable,
  session-local `path` built-in; keep explicit `run /path/program.exec`.
- 🟢 Build and package the Essentials file commands and `edit.exec` and
  `hexedit.exec` using checked file, metadata, directory, and terminal calls;
  exercise read and write operations on a disposable `/data` volume with
  `make test-userland-essentials`.
- 🟢 Apply the shell's working directory to external commands through the
  child start record.
- 🟢 Expose the start-record environment and working directory to programs,
  propagate them on launch, and implement `set`, `export`, and `unset`. Make
  `PATH` an inherited environment value while preserving `path` editing.
- 🟢 Return distinct missing, malformed, and permission-denied launch
  results to the shell; report terminal end-of-input and leave the session
  cleanly. Preserve the existing nonzero-exit and fault handling.
- 🟢 Exercise bare `cat /hello.txt`, `ls /`, and `version` through `PATH`
  using both COM1 and USB keyboard input; compare serial and framebuffer
  output, then repeat successful and failed launches while checking
  descriptor, page, mapping, and input-queue counts.

### Exit test

`cat /hello.txt`, `ls /`, and `version` resolve through `PATH` as external
programs over COM1 and USB keyboard input. Their output is identical on the
serial and framebuffer terminals. Repeated read-only and failed launches
have no page, descriptor, mapping, queue, or partial-output leak.

`make test-userland-stage2` passes on AHCI and NVMe. The shell marks the
kernel's managed-page allocator after each input line and reclaims command
allocations before the next line when no filesystem mutation, child terminal
input, live descriptor, or mapping change occurred. The test confirms stable
allocator, descriptor, mapping, and queue counters over repeated successful
and missing-image launches. Commands that mutate `/data` retain their
allocations because HyFS 2 may still reference new metadata; later allocator
ownership work should release those safely.

## Stage 3: directory-capable system image

HyFS 2 already supplies nested directories, metadata, and transactional
writes on the separate `/data` volume. This stage completes the packaged
system image and recovery checks; the boot root stays read-only.

- 🟢 Create `/System`, `/System/Bin`, `/Applications`, `/Users`, `/Volumes`, and
  `/Temporary`.
- 🟢 Package system components and applications into the paths documented in
  `src/README.md` and `src/userland/system/README.md`.
- 🟢 Preserve read-only mounting and recovery when a volume is damaged or removed.

The HyFS 2 format, stable identifiers, metadata/CRC validation, transactional
creation/replacement, and flush behavior are kernel/storage responsibilities;
their contract and remaining removable-media write policy are tracked in
`../../docs/hyfs-v2.md` and `../../docs/hyfs2-plan.md`, rather than as
unimplemented userland features. `make test-userland-stage3` covers the
packaged tree and fallback from missing, invalid, or corrupt system images.

### Exit test

The kernel mounts the directory-capable root on AHCI and NVMe, traverses the
system hierarchy, rejects corrupted metadata, and continues to expose the
recovery shell when the userland image is missing or invalid.

`make test-userland-stage3` verifies the packaged hierarchy and executable
headers, then boots disposable AHCI and NVMe images with missing or malformed
`System.exec` and with both HyFS 2 superblocks corrupted. Each case reaches
an interactive `kmon>` without a writable volume.

## Stage 4: system manager and services

- 🟢 Install `/System/Core/System.exec` as the first user process.
- 🟢 Start it as PID 1 after the kernel mounts the root filesystem.
- 🟢 Track bounded kernel process records with parent IDs and exit/fault
  results, and exercise two runnable AUEX processes with isolated file owners
  and instruction-round scheduling in hosted tests.
- 🟢 Run live foreground children through the shared scheduler while the
  parent waits, with per-process file owners and bounded instruction quanta.
- 🟢 Restart a failed command shell at most three times under PID 1; a normal
  exit still returns to KMon.
- 🟢 Use parent/child process records for live AUEX spawn, readiness, wait,
  termination, exit cleanup, and bounded instruction-round scheduling.
- 🟡 Timer-backed sleep and multiple runnable AUEX processes work; native
  context switching and interrupt preemption remain.
- 🟡 Package a versioned startup manifest with ordered one-shot Device and
  Storage checks, readiness bounds, retry limits, and failure logging.
  Persistent service control and graceful shutdown remain.
- 🔴 Introduce a persistent `Launch.service` with a capability and IPC
  contract. Device and Storage are currently one-shot policy checks.
- 🟢 Keep a kernel recovery key or boot option that bypasses normal userland;
  `R` enters Rescue/KMon before PID 1 and `D` enters debug KMon.

### Exit test

PID 1 starts the command shell, restarts one deliberately failed service up to
its declared limit, records the cause, and keeps the recovery console usable.
No service executes in an interrupt handler or retains resources after exit.

## Stage 5: IPC and capabilities

- 🟢 Implement a kernel-owned bounded channel table with versioned copied
  messages, PID ownership checks, stale-handle rejection, and cleanup when a
  process exits; hosted tests exercise its bounds and isolation.
- 🟡 Expose bounded message channels with checked open, accept, send, receive,
  wait, peer, and close calls. General event waits and shared buffers remain.
- 🟢 Authenticate channel peers by kernel process identity; only a parent
  granted the channel capability can open a channel to its live child.
- 🔴 Grant capabilities for devices, mounts, process inspection, system settings,
  display ownership, input routing, and service control.
- 🟡 Load path grants from the read-only `AUSC1` system manifest; malformed or
  missing policies grant nothing. Per-application requests and approvals remain.
- 🟡 Channel versions are checked on send and accept; service-specific
  protocol definitions remain.

### Exit test

An unprivileged application can use terminal and file services but cannot
control mounts, enumerate protected processes, or map the framebuffer. Closing
either endpoint releases queued messages and channel-owned resources; shared
buffers remain a separate planned extension.

## Stage 6: sessions and graphical userland

- 🔴 Add `Login.exec` and a session manager with per-session environment,
  working directory, terminal, and process ownership. A login screen may
  select or start a session here; it is not a security boundary until the
  kernel enforces identity, access rules, and process isolation.
- 🔴 Give `Display.service` exclusive display and routed-input capabilities.
- 🔴 Implement a compositor, window protocol, surfaces, damage tracking, pointer
  events, focus, and keyboard routing in userland.
- 🔴 Build `DesktopShell.appb`, then `Terminal.appb` and `Explorer.appb` against
  the public display and launch protocols.
- 🟢 Keep text-only startup as a supported configuration; it is the current
  default and must remain available when graphical sessions are added.

### Exit test

A graphical session starts after login, opens a terminal, launches an external
command, and recovers when a client submits an invalid surface or exits during
input delivery. COM1 continues to provide an independent recovery console.

## Stage 7: native user mode and hardening

The ring-3 page tables, exception handling, native syscall entry, and hardware
validation belong to the kernel, bootloader, and compiler checklists. The
kernel already runs bounded AUN1 children and contains their faults on AHCI
and NVMe. The remaining native terminal, file, IPC, and scheduling contracts
are tracked in `../kernel/README.md` and `../../PLAN.md`.

- 🔴 Port system programs and command-line tools after the native syscall and
  compiler target contracts are available; keep the AUEX image as a checked
  compatibility path during migration.
- 🔴 Add user and session policy only after protected identity, credential,
  permission, and audit mechanisms exist. Until then `Login.exec` can select
  a session but cannot claim to authenticate users.

Physical-machine validation, package trust, update/recovery policy, and
resource-limit gates are OS-wide release work in `../../PLAN.md`, not
userland-only implementation items.

### Exit test

Native user code cannot read or write kernel pages, cannot invoke privileged
instructions, and cannot impersonate a service. A process fault terminates only
that process and returns its resources while PID 1 and both recovery terminals
remain operational.

## Stage 2 handoff

Stage 1 provides checked process inputs, local method calls, byte arrays,
dynamic file access, and foreground process results. Stage 2 moved normal
commands into separate executables under `/System/Bin` and uses the HyFS 2
hierarchy and executable search path to launch them. KMon remains a separate
kernel recovery console. The current native AUN1 path is intentionally smaller
than the AUEX command runtime.
