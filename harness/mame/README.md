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
- XTMax MMIO or option ROM behavior
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
- `lua/assert_textmode_dir.lua`: DOS text-mode assertion script used by `run-driver-tests.sh`
- `lua/post_and_assert.lua`: prompt-gated DOS driver-test script for the working `ibm5160`/`rev2` path
- `verify-roms.sh`: check for the exact ROM filenames the stock machine target expects
- `config/mame.ini.template`: repo-local MAME config template
- `roms/`: repo-local ROM files
- `artifacts/`: generated state, ROM zips, cfg, nvram, snapshots, and other local runtime files

## Notes

- The bootstrap prefers a system package manager (`apt`, `dnf`, `pacman`, or `brew`).
- If MAME is already installed, export `MAME_BIN` to override discovery.
- This harness intentionally does not download PC BIOS ROM sets or DOS images.
- `run-driver-tests.sh` now defaults to a clean temporary MAME session so stale cfg/nvram state does not pollute DOS automation.
