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

Override the auto-typed command stream if needed:

```bash
XTMAX_MAME_AUTObOOT_COMMAND=$'B:\rDIR\rTYPE README.TXT\r' \
DOS_BOOT_FLOPPY=/path/to/dos-boot.img \
./harness/mame/run-driver-tests.sh
```

For deeper DOS-driver coverage, prepare a boot floppy with the desired `CONFIG.SYS` / `AUTOEXEC.BAT` content and point `DOS_BOOT_FLOPPY` at it.

## ROM Notes

- Stock MAME usually expects machine ROM sets named for the target machine, for example `ibm5160.zip`.
- Loose ROM binaries can also be used from `harness/mame/roms/` or via `XTMAX_MAME_EXTRA_ROMPATH`, but MAME still expects the filenames it knows for that machine.
- The two BIOS files currently in `../` are the `5160` pair, which also covers `ibm5155`.

## Layout

- `bootstrap.sh`: install or detect MAME, then create local MAME config/state directories
- `run-smoke.sh`: launch a stock-MAME smoke test with the XTMax floppy image
- `run-driver-tests.sh`: same flow, but expects a DOS boot floppy and types commands after boot
- `verify-roms.sh`: check for the exact ROM filenames the stock machine target expects
- `config/mame.ini.template`: repo-local MAME config template
- `roms/`: repo-local ROM files
- `artifacts/`: generated state, ROM zips, cfg, nvram, snapshots, and other local runtime files

## Notes

- The bootstrap prefers a system package manager (`apt`, `dnf`, `pacman`, or `brew`).
- If MAME is already installed, export `MAME_BIN` to override discovery.
- This harness intentionally does not download PC BIOS ROM sets or DOS images.
