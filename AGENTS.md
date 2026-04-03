# XTMax Repository Guide

Maintainer guidance for automated agents and contributors. For the human-facing overview, start with [README.md](./README.md). For source-vs-generated distinctions, use [docs/REPO_LAYOUT.md](./docs/REPO_LAYOUT.md).

## What Lives Here

XTMax is an 8-bit ISA card built around a Teensy 4.1. This repo contains:

- Teensy firmware in [firmware/teensy](./firmware/teensy)
- Boot ROM and DOS drivers in [software](./software)
- floppy-image tooling in [scripts](./scripts)
- MAME harnesses and an external XTMax device model patch in [harness/mame](./harness/mame)
- host-side USB-link tooling in [host/xtmax-host](./host/xtmax-host)
- KiCad hardware files in [hardware](./hardware)

## Start Points By Task

| Task | Start here |
|------|------------|
| Firmware build, hardware bring-up, 5155 troubleshooting | [firmware/teensy/AGENTS.md](./firmware/teensy/AGENTS.md) |
| I/O decode, ROM placement, AUX register map | [firmware/teensy/IO_PORTS.md](./firmware/teensy/IO_PORTS.md) |
| Boot ROM and DOS driver behavior | [software/README.md](./software/README.md) |
| USB host-link CLI and text mirror | [host/xtmax-host/README.md](./host/xtmax-host/README.md) |
| Screen mirror and keyboard-injection design | [docs/SCREEN_MIRROR_AND_KEY_INJECTION.md](./docs/SCREEN_MIRROR_AND_KEY_INJECTION.md) |
| Emulator-based regression work | [harness/mame/README.md](./harness/mame/README.md) |
| Floppy images and image builder | [images/README.txt](./images/README.txt) and [scripts/build_xtmax_floppy.py](./scripts/build_xtmax_floppy.py) |

## Fast Verification Commands

Run from the repository root unless noted.

### Host-side tests

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
cargo test --manifest-path host/xtmax-host/Cargo.toml
```

### Teensy firmware build

```bash
arduino-cli compile --fqbn teensy:avr:teensy41 firmware/teensy
```

### Boot ROM refresh

Run from [software/bootrom](./software/bootrom) after editing [bootrom.asm](./software/bootrom/bootrom.asm):

```bash
nasm -f bin -o bootrom bootrom.asm
python3 checksum.py
python3 generate_header.py
```

This regenerates:

- [firmware/teensy/bootrom.bin](./firmware/teensy/bootrom.bin)
- [firmware/teensy/bootrom.h](./firmware/teensy/bootrom.h)

### Floppy-image refresh

```bash
pip install -r scripts/requirements-floppy.txt
python3 scripts/build_xtmax_floppy.py
```

### MAME regression harness

The XTMax MAME patch and tests live under [harness/mame](./harness/mame). The main entrypoints are:

```bash
./harness/mame/run-xtmax-bootrom-tests.sh
./harness/mame/run-xtmax-storage-tests.sh
./harness/mame/run-xtmax-ems-tests.sh
./harness/mame/run-xtmax-menu-tests.sh
./harness/mame/run-xtmax-mirror-tests.sh
```

These validate the XT-visible contract in the MAME XTMax device model. They do not run the real Teensy firmware.

## Coordination Rules

- Edit primary sources first. Regenerate checked-in artifacts in the same change when practical.
- If you change Boot ROM protocol or SD register behavior, update both:
  - [firmware/teensy](./firmware/teensy)
  - [software/bootrom](./software/bootrom)
- If you change the AUX block at `0x290-0x297`, update all affected pieces together:
  - [firmware/teensy/xtmax_core.cpp](./firmware/teensy/xtmax_core.cpp)
  - [firmware/teensy/teensy.ino](./firmware/teensy/teensy.ino)
  - [host/xtmax-host](./host/xtmax-host)
  - [harness/mame/patches/0001-add-xtmax-phase1-card.patch](./harness/mame/patches/0001-add-xtmax-phase1-card.patch)
- If you change `MMAN_BASE`, `SD_BASE`, `AUX_BASE`, or ROM mapping assumptions, re-check [firmware/teensy/IO_PORTS.md](./firmware/teensy/IO_PORTS.md) and the Boot ROM assumptions in [software/README.md](./software/README.md).

## Practical Constraints

- Hardware validation is still required for real ISA timing, PSRAM behavior, and the Teensy USB-link path.
- The tree intentionally mixes source with generated artifacts and ready-to-use binaries. Do not treat generated files as the canonical source of truth.
- The current MAME XTMax device model is for regression coverage of external behavior. It is not a replacement for testing on a real XT.
- Keep scope tight. Avoid unrelated renames, artifact churn, or broad cleanup unless the task specifically calls for it.
