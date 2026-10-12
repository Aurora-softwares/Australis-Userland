# Australis userland plan

This directory is the planned home of operating-system programs that execute
above the kernel. The GUI is one userland subsystem. Command-line tools,
services, login, sessions, and the desktop all use the same process boundary.

The current kernel shell remains the recovery console until the userland shell
can boot, launch commands, and survive failed programs on both storage paths.

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

| Command | Description |
| --- | --- |
| `help` | Display available commands |
| `cd` | Change directory |
| `ls` | List files and directories |
| `pwd` | Print working directory |
| `cat` | Display file contents |
| `echo` | Print text |
| `clear` | Clear terminal |
| `exit` | Exit the shell |
| `history` | Display previous commands |
| `tree` | Display directory structure |
| `mkdir` | Create directories |
| `touch` | Create empty files |
| `cp` | Copy files |
| `mv` | Move or rename files |
| `rm` | Remove files |

### File utilities

| Command | Purpose |
| --- | --- |
| **`edit`** | Terminal text editor |
| **`view`** | Read-only text viewer |
| **`hexedit`** | Hexadecimal file editor |
| **`hexview`** | Hexadecimal file viewer |
| **`finfo`** | Detailed file information |

### System administration

| Command | Purpose |
| --- | --- |
| `sysinfo` | Display system information |
| `uptime` | Display system uptime |
| `mem` | Display memory usage |
| `ps` | List processes |
| `kill` | Terminate processes |
| `top` | Interactive process monitor |
| `devices` | Display detected devices |
| `drivers` | Display installed drivers |
| `services` | Manage system services |
| `mount` | Mount filesystems |
| `umount` | Unmount filesystems |
| `df` | Display filesystem capacity |
| `dmesg` | Display kernel messages |
| `reboot` | Restart Australis |
| `shutdown` | Shut down Australis |

## Stage 1: process inputs and application runtime

### Kernel and AUEX

- [x] Define a versioned process-start record containing `argc`, `argv`,
  environment entries, working directory, and standard descriptors.
- [x] Copy all start data through checked user memory and reject malformed counts,
  lengths, pointers, and duplicate ownership.
- [x] Add syscall results with explicit success, end-of-file, retry, invalid
  argument, not found, permission, and I/O error states.
- [x] Add dynamic-path open calls and read-only system-information queries.
- [x] Add process identifiers plus foreground `spawn`, `wait`, and exit status.

### Compiler

- [x] Populate `Main(string[] args)` for `type = "exec"` projects in the
  recovery shell, with bounded argument count, indexing, comparison, length,
  and output.
- [x] Add scalar locals, integer and Boolean operations, comparisons,
  branches, loops, `break`, `continue`, and computed console output and exits
  to the AUEX backend.
- [x] Add application method calls to the AUEX backend.
- [x] Add bounded strings and byte arrays backed by the user data region.
- [x] Preserve the existing AUEX validation, CRC, instruction limit, and cleanup
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
The stage 1 starter project in this directory prints its arguments and exits
successfully; build it with
`build/hydrogen-apps build src/userland/australlis.userland.hyproj -o build/userland.exec`.

## Stage 2: external command shell

- Move `cat`, `version`, `echo`, and `pwd` into independent `type = "exec"`
  projects.
- Add user-facing directory enumeration and metadata, then move `ls` out of
  the kernel shell.
- Implement shell variables and `PATH` lookup. Start with
  `PATH=/Bin:/System/Bin` once filesystem directories exist.
- Keep `cd`, `set`, `export`, `unset`, and `exit` as shell built-ins.
- Retain explicit `run /path/program.exec` during the transition.
- Return command-not-found, invalid executable, signal/fault, and exit-status
  information without losing the interactive terminal.

### Exit test

`cat /hello.txt`, `ls /`, and `version` resolve through `PATH` as external
programs over COM1 and USB keyboard input. Their output is identical on the
serial and framebuffer terminals. Repeated execution has no page, descriptor,
mapping, queue, or partial-output leak.

## Stage 3: directory-capable system image

- Define a directory-capable HyFS revision with stable identifiers, checked
  metadata, file lengths, directory entries, and CRC coverage.
- Add atomic creation and replacement primitives before enabling general
  writes. Add flush semantics before removable-media writes.
- Create `/System`, `/Bin`, `/Applications`, `/Users`, `/Volumes`, and
  `/Temporary`.
- Package system components and applications into the paths documented in
  `src/system/README.md`.
- Preserve read-only mounting and recovery when a volume is damaged or removed.

### Exit test

The kernel mounts the directory-capable root on AHCI and NVMe, traverses the
system hierarchy, rejects corrupted metadata, and continues to expose the
recovery shell when the userland image is missing or invalid.

## Stage 4: system manager and services

- Install `/System/Core/System.exec` as the first user process.
- Start it as PID 1 after the kernel mounts the root filesystem.
- Add a process table with parent, child, running, blocked, exited, and faulted
  states.
- Support multiple runnable processes, blocking waits, timers, and preemption.
- Define service manifests, dependency ordering, readiness, restart limits,
  shutdown, and structured failure records.
- Introduce `Device.service`, `Storage.service`, and `Launch.service` as policy
  services over kernel APIs.
- Keep a kernel recovery key or boot option that bypasses normal userland.

### Exit test

PID 1 starts the command shell, restarts one deliberately failed service up to
its declared limit, records the cause, and keeps the recovery console usable.
No service executes in an interrupt handler or retains resources after exit.

## Stage 5: IPC and capabilities

- Add bounded message channels, event waiting, process handles, and shared
  buffers with explicit ownership.
- Authenticate peers by kernel process identity rather than filenames.
- Grant capabilities for devices, mounts, process inspection, system settings,
  display ownership, input routing, and service control.
- Make application manifests request capabilities; the launcher supplies only
  the approved subset.
- Version every public service protocol and reject incompatible messages.

### Exit test

An unprivileged application can use terminal and file services but cannot
control mounts, enumerate protected processes, or map the framebuffer. Closing
either endpoint releases queued messages and shared pages.

## Stage 6: sessions and graphical userland

- Add `Login.exec` and a session manager with per-session environment,
  working directory, terminal, and process ownership.
- Give `Display.service` exclusive display and routed-input capabilities.
- Implement a compositor, window protocol, surfaces, damage tracking, pointer
  events, focus, and keyboard routing in userland.
- Build `DesktopShell.appb`, then `Terminal.appb` and `Explorer.appb` against
  the public display and launch protocols.
- Keep text-only startup as a supported configuration.

### Exit test

A graphical session starts after login, opens a terminal, launches an external
command, and recovers when a client submits an invalid surface or exits during
input delivery. COM1 continues to provide an independent recovery console.

## Stage 7: native user mode and hardening

- Add ring-3 execution, per-process page tables, user/supervisor permissions,
  guarded user stacks, syscall entry/return, and user exception delivery.
- Port the established AUEX process and syscall contracts to native code while
  retaining AUEX as a deterministic compatibility format if useful.
- Add users, groups, permissions, signed system packages, secure update and
  recovery policy, resource limits, and audit records.
- Validate on physical machines in addition to the QEMU matrix.

### Exit test

Native user code cannot read or write kernel pages, cannot invoke privileged
instructions, and cannot impersonate a service. A process fault terminates only
that process and returns its resources while PID 1 and both recovery terminals
remain operational.

## Stage 2 handoff

Stage 1 provides checked process inputs, local method calls, byte arrays,
dynamic read-only file access, and foreground process results. Stage 2 will
move recovery-shell commands into separate executables and use the existing
HyFS 2 hierarchy and executable search path to launch them.
