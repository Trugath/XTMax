# MAME Harness

This harness keeps MAME-related setup separate from the main XTMax source tree.

It is designed to:
- keep MAME out of git
- keep generated state inside `harness/mame/artifacts/`
- make stock-MAME smoke testing easy
- leave room for a later, opt-in custom XTMax device model if deeper emulation is needed

What this harness can validate with stock MAME:
- that a known PC/XT machine boots with the selected ROM set
- that the XTMax floppy image mounts cleanly
- that a user-supplied DOS boot floppy can boot and run commands against the XTMax disk
- that the DOS-side smoke flow visibly reaches the XTMax floppy listing in text mode

What it does not validate yet:
- Teensy firmware timing
- full XTMax MMIO or option ROM behavior through a device model
- EMS/UMB mapping through a custom XTMax ISA device

## Quick Start

1. Run the bootstrap:

```bash
./harness/mame/bootstrap.sh
```

2. Put a compatible MAME ROM zip or loose BIOS files in:

```text
harness/mame/roms/
```

Typical example:
- `ibm5160.zip` for `MAME_MACHINE=ibm5160`
- `ibm5160.zip` for `MAME_MACHINE=ibm5155` as well
- `ibm5150.zip` for `MAME_MACHINE=ibm5150`

The repo currently includes the `5160` BIOS pair in `harness/mame/roms/`.

If you already keep ROM files outside the repo, point MAME at that directory as an extra search path:

```bash
XTMAX_MAME_EXTRA_ROMPATH=../ ./harness/mame/run-smoke.sh
```

The harness will append that path to MAME's `rompath` rather than copying anything into the repo.

3. Run a basic smoke session:

```bash
./harness/mame/run-smoke.sh
```

This uses `images/xtmax360.img` by default.

Override the machine or BIOS if needed:

```bash
MAME_MACHINE=ibm5160 MAME_BIOS=rev2 ./harness/mame/run-smoke.sh
```

Before launching, you can check the expected ROM filenames:

```bash
./harness/mame/verify-roms.sh
```

## XTMax Device Model

There is now an opt-in external patchset for a first XTMax ISA device model.

Phase 1 is intentionally narrow:
- maps the XTMax option ROM at `0xCE000`
- exposes the XTMax MMAN ports at `0x260-0x26F`
- exposes the XTMax SD ports at `0x280-0x287`
- stubs the SD path to a deterministic timeout so the Boot ROM can execute and reach its failure path

The current patch is now effectively a phase-2 storage slice:
- the SD command path is modeled at the byte-stream level
- the ROM-adjacent SD window at `0xCE800-0xCEFFF` is modeled
- a raw host image can back the emulated SD card through `XTMAX_MAME_SD_IMAGE`

What phase 1 does not emulate yet:
- PSRAM backing
- EMS/UMB memory windows
- the Teensy firmware itself

Fetch and patch a separate `mame0264` source tree like this:

```bash
./harness/mame/build-mame-xtmax.sh --skip-build
```

Then build it:

```bash
./harness/mame/build-mame-xtmax.sh
```

The patched tree lives under `harness/mame/artifacts/` and is ignored by git.

Once built, run the XTMax device assertion flow:

```bash
./harness/mame/run-xtmax-device-tests.sh
```

By default that uses:
- machine: `ibm5160`
- BIOS: `rev2`
- slot: `isa5`
- a generated raw SD image at `harness/mame/artifacts/xtmax-sd.img`
- a generated boot sector that prints `XTMAX TEST BOOT`
- expected text: `XTMAX TEST BOOT`

That SD image is created automatically on first run from `harness/mame/boot/xtmax_test_boot.asm` and is treated as raw 512-byte sectors. Set `XTMAX_MAME_KEEP_EXISTING_SD_IMAGE=1` to reuse an existing image instead of regenerating it.

For a two-branch Boot ROM regression, run:

```bash
./harness/mame/run-xtmax-bootrom-tests.sh
```

That runs:
- a success case with a generated boot sector that prints `XTMAX TEST BOOT`
- an invalid-boot-sector case that asserts the ROM reports `No boot media`

For a ROM service-loader regression, run:

```bash
./harness/mame/run-xtmax-menu-tests.sh
```

That presses `X` at the ROM prompt, loads a synthetic stage-1 payload from reserved SD sectors, asserts that the payload runs, and then confirms normal boot resumes afterward.

The current synthetic stage is a real menu, not just a banner:
- `S` boots from the XTMax SD path immediately
- `F` tries floppy boot immediately
- `D` runs a simple SD boot-sector diagnostic
- `C`, `Esc`, or `Enter` return to the Boot ROM so normal boot can continue

For a Boot ROM INT 13h storage regression, run:

```bash
./harness/mame/run-xtmax-storage-tests.sh
```

That uses a generated boot sector that:
- boots through the XTMax ROM
- writes sector 2 through the XTMax INT 13h path
- reads sector 2 back through the same XTMax path
- compares the buffers in memory
- prints `XTMAX RW OK` on success

For an EMS page-frame regression, run:

```bash
./harness/mame/run-xtmax-ems-tests.sh
```

That uses a generated boot sector that:
- boots through the XTMax ROM
- programs the MMAN EMS registers at `0x260-0x26F`
- maps a 64 KB EMS frame at `0xE0000`
- writes distinct bytes through two 16 KB windows
- remaps the EMS frame pointers
- verifies the remapped windows expose the expected PSRAM-backed data
- prints `XTMAX EMS OK` on success

To force the old no-card failure-path test instead:

```bash
XTMAX_MAME_NO_SD_IMAGE=1 ./harness/mame/run-xtmax-device-tests.sh
```

To point the device model at a specific raw image:

```bash
XTMAX_MAME_SD_IMAGE=/path/to/disk.img ./harness/mame/run-xtmax-device-tests.sh
```

This keeps the custom MAME work completely outside the main repo history while still letting the repo carry the patchset and automation.

## DOS Session Automation

To exercise the XTMax floppy image inside DOS, provide a bootable DOS floppy image:

```bash
DOS_BOOT_FLOPPY=/path/to/dos-boot.img ./harness/mame/run-driver-tests.sh
```

Defaults:
- machine: `ibm5155`
- XTMax floppy: `images/xtmax360.img`
- DOS command stream: `B:` then `DIR`
- default assertions: `B>`, `XTSD.SYS`, `XTEMM.EXE`, `XTUMBS.SYS`

The `ibm5155` target currently appears to stall in stock MAME after `640 KB OK` even with no floppy present. For a working DOS-side integration path, use the XT motherboard with the matching 11/08/82 BIOS:

```bash
MAME_MACHINE=ibm5160 MAME_BIOS=rev2 \
DOS_BOOT_FLOPPY=/path/to/dos-boot.img \
./harness/mame/run-driver-tests.sh
```

In that configuration the harness uses a prompt-gated Lua flow:
- starts a clean MAME session by default
- waits until `A:\>` is visible
- posts `B:` and `DIR` through MAME's natural keyboard manager
- asserts that the XTMax disk listing appears on screen

If you need the older direct autoboot-command flow, force it explicitly:

```bash
XTMAX_MAME_DRIVER_FLOW=autoboot \
DOS_BOOT_FLOPPY=/path/to/dos-boot.img \
./harness/mame/run-driver-tests.sh
```

Override the auto-typed command stream if needed:

```bash
XTMAX_MAME_AUTObOOT_COMMAND=$'B:\rDIR\rTYPE README.TXT\r' \
DOS_BOOT_FLOPPY=/path/to/dos-boot.img \
./harness/mame/run-driver-tests.sh
```

For deeper DOS-driver coverage, prepare a boot floppy with the desired `CONFIG.SYS` / `AUTOEXEC.BAT` content and point `DOS_BOOT_FLOPPY` at it.

The DOS harness now uses a Lua script to read text-mode video memory and assert that the expected XTMax disk listing appears on screen. Override the expected text if needed:

```bash
XTMAX_MAME_EXPECT_TEXT='B>|README.TXT' \
DOS_BOOT_FLOPPY=/path/to/dos-boot.img \
./harness/mame/run-driver-tests.sh
```

For prompt-gated Lua posting, override the prompt text or posted command sequence like this:

```bash
MAME_MACHINE=ibm5160 MAME_BIOS=rev2 \
XTMAX_MAME_POST_WHEN_TEXT='A:\\>' \
XTMAX_MAME_POST_CODED='B:\\rDIR\\rTYPE README.TXT\\r' \
DOS_BOOT_FLOPPY=/path/to/dos-boot.img \
./harness/mame/run-driver-tests.sh
```

## ROM Notes

- Stock MAME usually expects machine ROM sets named for the target machine, for example `ibm5160.zip`.
- Loose ROM binaries can also be used from `harness/mame/roms/` or via `XTMAX_MAME_EXTRA_ROMPATH`, but MAME still expects the filenames it knows for that machine.
- The two BIOS files currently in `../` are the `5160` pair, which also covers `ibm5155`.

## Layout

- `bootstrap.sh`: install or detect MAME, then create local MAME config/state directories
- `run-smoke.sh`: launch a stock-MAME smoke test with the XTMax floppy image
- `run-driver-tests.sh`: same flow, but expects a DOS boot floppy and types commands after boot
- `build-mame-xtmax.sh`: fetch, patch, and optionally build a separate `mame0264` tree with the XTMax phase-1 ISA device
- `run-xtmax-device-tests.sh`: run the patched MAME binary and assert the XTMax Boot ROM path on screen
- `run-xtmax-menu-tests.sh`: run the patched MAME binary and assert the XTMax ROM service-loader path on screen
- `lua/assert_textmode_dir.lua`: DOS text-mode assertion script used by `run-driver-tests.sh`
- `lua/post_and_assert.lua`: prompt-gated DOS driver-test script for the working `ibm5160`/`rev2` path
- `patches/0001-add-xtmax-phase1-card.patch`: external MAME patch for the XTMax phase-1 device
- `verify-roms.sh`: check for the exact ROM filenames the stock machine target expects
- `config/mame.ini.template`: repo-local MAME config template
- `roms/`: repo-local ROM files
- `artifacts/`: generated state, ROM zips, cfg, nvram, snapshots, and other local runtime files

## Notes

- The bootstrap prefers a system package manager (`apt`, `dnf`, `pacman`, or `brew`).
- If MAME is already installed, export `MAME_BIN` to override discovery.
- This harness intentionally does not download PC BIOS ROM sets or DOS images.
- `run-driver-tests.sh` now defaults to a clean temporary MAME session so stale cfg/nvram state does not pollute DOS automation.
