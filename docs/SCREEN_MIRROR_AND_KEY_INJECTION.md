# Screen Mirror And Keyboard Injection Design

## Purpose

This document defines a focused XTMax extension for:

- screen mirroring from the target PC to a host machine over the Teensy's USB connection
- keyboard key injection from the host machine back into the target PC
- a related path for host-side SD card management over USB

The goal is remote-console style operation for text-mode bring-up, BIOS work, DOS setup, and debugging.

## Scope

### In Scope

- passive capture of display-related ISA activity
- host-side reconstruction of MDA and CGA text screens
- optional later support for CGA graphics modes
- host-to-target key injection
- design consideration for host-side SD card access and remote file management
- boot-time use from the XTMax Boot ROM service menu
- DOS-time use through a small resident helper that feeds the BIOS keyboard buffer

### Out Of Scope

- full raw ISA tracing
- cycle-accurate emulation of video adapters
- direct electrical emulation of the XT keyboard cable/protocol
- support for programs that bypass BIOS keyboard services and talk directly to motherboard keyboard hardware
- high-fidelity Hercules or EGA/VGA emulation

## Recommended Host Language

The host-side binary should be written in **Rust**.

Reasons:

- strong fit for long-running binary stream parsers
- good performance for real-time decode and rendering
- simple cross-platform single-binary distribution
- safe concurrency for transport, decode, and UI threads
- good library options for USB serial and graphics

Recommended host stack:

- language: `Rust`
- USB transport: `serialport`
- renderer/window/input: `SDL2` first, `wgpu` only if later needed
- optional recording/replay format: custom binary log with versioned headers

Python is acceptable for quick protocol experiments, but not as the primary production binary.

## Design Summary

The design is intentionally asymmetric:

- the Teensy does **real-time capture, filtering, buffering, and USB streaming**
- the host does **decode, rendering, UI, and key event generation**
- the XT sees keyboard injection through a **software-consumed queue**, not through fake motherboard keyboard wires

That split keeps the timing-sensitive work on the Teensy and keeps the ISA path independent from the host.

## Why Keyboard Injection Is BIOS-Level In V1

XTMax is an ISA card. It does not have a physical connection to the motherboard keyboard clock/data lines.

Therefore, V1 key injection should not try to pretend to be the real XT keyboard electrically. Instead:

- the host sends key events to the Teensy over USB
- the Teensy queues them
- Boot ROM menu code or a DOS-side helper reads the queue from XTMax I/O ports
- that software writes translated keys into the BIOS keyboard buffer at `0x40:0x1E`

This gives useful remote control for:

- Boot ROM service menu
- BIOS or DOS software that uses BIOS keyboard services
- command-line tools and most setup utilities

It will not control software that bypasses BIOS keyboard services and bangs the XT keyboard hardware directly. That is acceptable for V1.

## Supported Video Modes

### Phase 1

- MDA text
- CGA 40x25 text
- CGA 80x25 text

### Phase 2

- CGA 320x200 4-color graphics
- CGA 640x200 2-color graphics

### Not Planned For Initial Work

- Hercules graphics
- EGA/VGA
- adapter-specific snow/artifact emulation

## ISA Activity To Capture

Only display-relevant traffic should be mirrored.

### Memory Writes

- `0xB0000-0xB7FFF` for MDA text memory
- `0xB8000-0xBFFFF` for CGA text and graphics memory

Only **writes** are needed for mirroring.

### I/O Writes

- `0x3B0-0x3BF` for MDA/Herc-compatible controller registers
- `0x3D0-0x3DF` for CGA controller registers

These writes are used to track:

- CRTC index/data state
- cursor position and shape
- mode control
- active page and layout hints

### Not Needed

- general memory reads
- general I/O reads
- non-video memory
- unrelated adapter registers

## XTMax Firmware Architecture

Add a new optional subsystem in the Teensy firmware:

1. `mirror_capture`
2. `mirror_stream`
3. `host_command`
4. `xt_keyboard_queue`

### 1. `mirror_capture`

Hooks into the existing ISA service path and watches only:

- writes to mirrored display memory
- writes to mirrored display I/O ports

For each relevant write, it emits a compact event into a ring buffer.

### 2. `mirror_stream`

Owns a USB-facing ring buffer and packetizer.

Rules:

- never block the ISA service path
- batch multiple events into one USB packet
- if the host falls behind, drop mirror events and emit an overflow marker
- do not let screen mirroring affect SD, EMS, or general XTMax timing

### 3. `host_command`

Consumes commands sent from the host over USB, such as:

- request snapshot
- enable or disable mirroring
- inject key press
- inject key release
- clear keyboard queue

### 4. `xt_keyboard_queue`

Stores host-generated key events until the target reads them through XTMax I/O ports.

This queue is separate from the screen mirror stream. Keyboard injection must still work even if mirroring is disabled.

## XT-Side I/O Register Proposal

The current XTMax decode already uses:

- `0x260-0x26F` for MMAN
- `0x280-0x287` for SD

Reserve a new auxiliary block at:

- `0x290-0x297`

This keeps the feature distinct from existing MMAN and SD behavior.

### Proposed Register Map

| Port | Name | Direction | Purpose |
|------|------|-----------|---------|
| `0x290` | `AUX_STATUS` | read | bit flags for key available, overflow, mirror enabled, host connected |
| `0x290` | `AUX_CONTROL` | write | clear overflow, enable mirror, reset queues |
| `0x291` | `KBD_ASCII` | read | next queued ASCII byte |
| `0x292` | `KBD_SCANCODE` | read | next queued BIOS/Set-1 scancode |
| `0x293` | `KBD_FLAGS` | read | modifier flags for current key event |
| `0x294` | `KBD_POP` | write | acknowledge and advance key queue |
| `0x295` | `MIRROR_DROPS_LO` | read | low byte of dropped-event counter |
| `0x296` | `MIRROR_DROPS_HI` | read | high byte of dropped-event counter |
| `0x297` | `AUX_VERSION` | read | protocol/feature version |

### Notes

- `KBD_ASCII` and `KBD_SCANCODE` are exposed separately so XT software can inject directly into the BIOS keyboard buffer.
- Keys should be queued as **translated BIOS-oriented events**, not raw host key names.
- `KBD_POP` keeps the interface simple and polling-friendly for Boot ROM and DOS helpers.

## USB Protocol

Use a framed binary protocol over the Teensy's USB serial channel for V1.

This is sufficient because screen mirroring bandwidth is modest once traffic is filtered to display-related writes only.

If needed later, the transport can move to a faster custom USB class without changing the high-level event model.

### Current Firmware Bootstrap Protocol

The first firmware slice can use a simple line-oriented USB serial protocol before the full framed transport exists.

Implemented commands:

- `K <ascii> <scancode> <flags>`
- `M <0|1>`
- `D <count>`
- `R`

Meaning:

- `K` queues one keyboard event into the XTMax auxiliary key queue
- `M` enables or disables the mirror feature flag
- `D` increments the mirror-drop counter
- `R` resets the auxiliary key queue and clears overflow

Examples:

```text
K 13 28 0
K 88 45 1
M 1
R
```

This bootstrap protocol is intentionally minimal and is expected to be replaced by the framed packet transport described below.

### Packet Types

- `HELLO`
- `CAPS`
- `VIDEO_MEM_WRITE`
- `VIDEO_IO_WRITE`
- `VIDEO_SNAPSHOT_BEGIN`
- `VIDEO_SNAPSHOT_DATA`
- `VIDEO_SNAPSHOT_END`
- `KEY_EVENT`
- `OVERFLOW`
- `STATS`

### Event Encoding

Use compact binary records. Example:

```text
packet_header {
  u8  type
  u8  flags
  u16 length
  u32 sequence
}
payload...
```

For video writes:

```text
VIDEO_MEM_WRITE
  u8  region      ; 0 = B000, 1 = B800
  u16 offset
  u8  value

VIDEO_IO_WRITE
  u16 port
  u8  value
```

For key events sent from host to Teensy:

```text
KEY_EVENT
  u8  action      ; press, release, or tap
  u8  ascii
  u8  scancode
  u8  flags       ; shift/ctrl/alt/etc
```

## Snapshot Model

Mirroring must support recovery after:

- host restart
- USB reconnect
- dropped-event overflow

So the host should be able to request a full snapshot.

### Snapshot Contents

- mirrored MDA text memory
- mirrored CGA memory
- relevant CRTC registers
- current active adapter guess
- cursor state

### Snapshot Behavior

1. host connects
2. host sends `HELLO`
3. Teensy replies with `CAPS`
4. host requests snapshot
5. Teensy sends snapshot packets
6. host switches to live event processing

If an `OVERFLOW` packet is seen, the host requests a fresh snapshot.

## Host Binary Architecture

Split the host binary into four logical modules.

### 1. `transport`

Responsibilities:

- open USB serial device
- frame packets
- validate lengths and sequence numbers
- send commands back to Teensy

### 2. `video_model`

Maintains a shadow representation of:

- MDA text VRAM
- CGA VRAM
- video register values
- cursor state
- current mode guess

This model is updated by events and snapshots.

### 3. `renderer`

Renders from `video_model`, not from raw event packets.

V1 renderer behavior:

- render text screens with a bundled bitmap font
- support 40-column and 80-column layouts
- render cursor when register state allows
- scale cleanly for modern displays

### 4. `input`

Maps local keyboard events to XT-friendly injected events.

Responsibilities:

- translate host key presses into ASCII + XT scancode pairs
- provide a small hotkey layer for host control, such as:
  - toggle mirror stats
  - request snapshot
  - disconnect gracefully

## Video Reconstruction Strategy

### Text Modes

V1 should reconstruct text entirely from:

- video RAM writes
- relevant CRTC and mode-control register writes

For text modes, a full video emulation is unnecessary. The host only needs:

- character bytes
- attribute bytes
- mode width
- cursor position

### Graphics Modes

For CGA graphics later:

- maintain full `B800` shadow memory
- derive pixel output from mode bits
- redraw the full frame on dirty updates or timed frame boundaries

This is a later phase, not required for the first delivery.

## Keyboard Injection Design

### Boot ROM Use

The Boot ROM service menu can poll `0x290-0x294` directly.

That enables remote control before DOS loads.

### DOS Use

Add a small helper such as `XTKBD.COM` or `XTKBD.SYS`.

Responsibilities:

- poll the XTMax key queue at a low periodic rate
- translate the queued event into a BIOS keyboard buffer entry
- write into the BIOS circular buffer at `0x40:0x1E`
- update BIOS head/tail pointers safely

This helper should be tiny and resident.

### BIOS Buffer Injection

The injected entry should match the BIOS convention:

- low byte: ASCII
- high byte: XT scan code

This keeps compatibility with:

- `INT 16h`
- DOS command line input
- most text-mode DOS tools

### Explicit Limitation

Programs that read the keyboard by talking directly to motherboard hardware instead of BIOS services will not see injected keys in V1.

That is an accepted limitation.

## SD Card Access Over USB

Screen mirroring and key injection naturally lead to the next feature: remote file management on the XTMax SD card from the host machine.

This is useful for:

- copying files to the machine without touching floppies
- retrieving logs, captures, and configuration files
- editing boot scripts and utilities remotely
- staging Boot ROM tools and diagnostics

However, this area has a harder correctness problem than mirroring or key injection:

- the XT may already be mounting and writing the same FAT filesystem
- the host must not make concurrent unsynchronized changes to the card
- raw shared block access can corrupt the filesystem

### Recommendation

Treat SD-over-USB as a **separate feature with explicit ownership modes**.

Do not expose the SD card to both the XT and the host for simultaneous raw read/write access.

## SD Access Modes

### Mode 1: Exclusive Raw Block Access

In this mode, the host accesses the SD card through the Teensy as a raw block device.

Use cases:

- card imaging
- backup and restore
- offline file edits
- preparing boot media

Rules:

- XT-side SD services must be disabled or detached
- Boot ROM and DOS driver must not be using the card
- firmware should expose a visible `host owns SD` state

Pros:

- simplest host implementation
- high throughput
- easy to map to standard tooling

Cons:

- cannot safely be used while the XT is running against the same card
- highest risk of FAT corruption if ownership is violated

This mode is acceptable for maintenance, but it is not the best "manage files on the machine remotely while it is live" solution.

### Mode 2: Live File Service Proxy

In this mode, the host does **not** mount the raw SD card directly.

Instead:

- the XT keeps normal ownership of the filesystem
- a DOS-side helper performs file operations locally on the target
- the host sends file-management requests over USB
- XTMax software on the target executes them and returns results

Example operations:

- list directory
- upload file
- download file
- rename
- delete
- make directory

Pros:

- safe while DOS is live
- no split-brain FAT ownership
- matches the "remote manage files on the machine" goal better

Cons:

- slower than raw block access
- needs a DOS-side agent
- depends on DOS being booted and the helper being resident

This should be the preferred mode for normal remote file management.

### Mode 3: Boot ROM Service Mode

In this mode, the Boot ROM service menu temporarily hands card ownership to the host before DOS boots.

Use cases:

- push boot tools
- replace config files
- recover a broken DOS install
- update stage payloads

This is effectively an exclusive-access mode, but exposed through the service menu rather than a separate maintenance workflow.

## Recommended SD Strategy

Use both models, but for different purposes:

- **normal live workflow**: file service proxy
- **maintenance workflow**: exclusive raw block access

That gives safe day-to-day operation while still preserving a strong recovery path.

## SD Firmware Design

Add an SD ownership state machine in the Teensy firmware:

- `XT_OWNED`
- `HOST_OWNED`
- `TRANSITION`

Rules:

- only one side may issue SD commands at a time
- transitions must flush pending writes
- ownership changes must be explicit
- the current owner must be visible to both host and XT software

Suggested host-visible USB commands:

- `SD_GET_STATE`
- `SD_REQUEST_HOST_OWNERSHIP`
- `SD_RELEASE_HOST_OWNERSHIP`
- `SD_READ_BLOCK`
- `SD_WRITE_BLOCK`
- `SD_FILE_PROXY_REQUEST`

Suggested XT-visible auxiliary status bits:

- host connected
- host owns SD
- SD busy
- file proxy available

## DOS-Side File Proxy Agent

If live file management is desired, add a resident DOS helper in addition to the keyboard helper.

Responsibilities:

- poll XTMax auxiliary registers for host requests
- perform DOS file operations locally
- return results in chunks

This helper should sit above DOS filesystem services rather than poking FAT structures directly.

That gives:

- better compatibility
- less chance of filesystem corruption
- simpler implementation

### Suggested Operations

- `DIR`
- `GET`
- `PUT`
- `DEL`
- `REN`
- `MKDIR`
- `RMDIR`
- optional `TYPE` or small-file readback

## Host-Side SD Management

The host binary can expose two distinct workflows.

### Live Session Workflow

Combine:

- screen mirror
- keyboard injection
- DOS-side file proxy

This gives a practical remote console:

- see the DOS screen
- type commands
- copy files in and out safely

### Maintenance Workflow

When the XT is not using the card:

- switch to `HOST_OWNED`
- expose raw image operations
- optionally mount or image the card from the host

The host UI should make the current mode obvious and refuse destructive operations when ownership is ambiguous.

## SD Safety Rules

These rules should be treated as hard requirements:

- never allow simultaneous unsynchronized raw writes from XT and host
- do not auto-switch SD ownership behind the user's back
- if the host owns the card, XT-side Boot ROM and DOS SD services must fail cleanly
- if the XT owns the card, host raw block writes must be rejected
- after any overflow or communication failure, default back to a safe ownership state

## Updated Delivery Plan

### Milestone 1

- Teensy capture of `B800` writes and `0x3D0-0x3DF`
- Rust host showing CGA text mirror
- manual snapshot button

### Milestone 2

- add `B000` and `0x3B0-0x3BF`
- support MDA text mirror
- add cursor rendering

### Milestone 3

- add XTMax auxiliary keyboard queue registers
- Boot ROM service menu polling of injected keys
- simple host key send support

### Milestone 4

- DOS resident keyboard helper
- practical remote DOS control

### Milestone 5

- DOS-side file proxy agent
- host upload/download and directory management

### Milestone 6

- exclusive raw SD ownership mode for maintenance and recovery

### Milestone 7

- optional CGA graphics mirror
- recording and replay

## Performance Constraints

### Screen Mirroring

Screen mirroring bandwidth is manageable because only filtered display writes are sent.

Typical traffic:

- text mode updates are sparse
- even full text-page snapshots are small
- controller register traffic is tiny

### Hard Rule

USB traffic must never block the ISA-side path.

If USB cannot keep up:

- drop mirror events
- increment overflow counter
- emit `OVERFLOW`
- keep card behavior correct for the XT

### Keyboard Injection

Keyboard injection bandwidth is trivial compared to video mirroring.

### SD Management

Live file proxy traffic is moderate and should coexist comfortably with screen mirroring and key injection.

Exclusive raw block mode can be heavier, but it runs only when the XT is not using the card.

## Failure Behavior

### If USB Is Unplugged

- mirroring stops
- XTMax continues normal ISA service
- key injection queue is disabled or drained safely

### If Host Decoder Falls Behind

- Teensy drops mirror events
- host requests a fresh snapshot on reconnect or overflow notice

### If XT-Side Keyboard Consumer Is Missing

- key queue eventually fills
- `AUX_STATUS` reports overflow
- host UI should display that injected keys are not being consumed

## File And Repo Impact

Expected new repo areas:

- `docs/SCREEN_MIRROR_AND_KEY_INJECTION.md`
- `firmware/teensy/` additions for mirror capture and USB framing
- `software/` addition for DOS keyboard helper
- `software/` addition for DOS file proxy helper
- new host tool project, likely under `tools/host-mirror/` or `host/xtmax-remote/`

The host binary should remain separate from the timing-sensitive firmware logic.

## Recommendation

Build V1 as:

- **text-mode screen mirror**
- **BIOS-buffer keyboard injection**

Do not attempt raw XT keyboard hardware emulation in the first version.

That gives the highest value with the lowest hardware risk and fits the actual physical constraints of XTMax as an ISA card with a USB-connected Teensy.
