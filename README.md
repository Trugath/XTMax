# XTMax

XTMax is an 8-bit ISA expansion card built around a Teensy 4.1. This repository contains the Teensy firmware, the BIOS extension ROM and DOS-side storage/memory drivers, floppy image tooling, and KiCad hardware files.

This repository is a forked extraction of the XTMax fragment originally published in the MicroCoreLabs Projects monorepo at [`XTMax/Code/XTMax`](https://github.com/MicroCoreLabs/Projects/tree/master/XTMax/Code/XTMax).

Unless a subdirectory or file says otherwise, this fork is distributed under the MIT license in [LICENSE](./LICENSE). Some bundled components keep their own original licensing, for example [software/sd/LICENSE.TXT](./software/sd/LICENSE.TXT).

## Repository Layout

- [`firmware/teensy`](./firmware/teensy): Teensy 4.1 firmware, generated Boot ROM header, and machine-specific notes.
- [`software`](./software): Boot ROM source, DOS storage/EMS/UMB drivers, prebuilt binaries, and legacy build toolchains.
- [`images`](./images): prebuilt MS-DOS driver disk images and notes.
- [`hardware`](./hardware): KiCad source files, schematic PDF, and generated fabrication outputs.
- [`scripts`](./scripts): host-side tooling, currently for building the floppy images.
- [`tests`](./tests): host-side verification for repo-maintained behaviors that can be checked without hardware.
- [`docs/REPO_LAYOUT.md`](./docs/REPO_LAYOUT.md): quick map of which files are primary sources, generated artifacts, and helper assets.

## Start Here

If you are trying to:

- Flash firmware: read [`firmware/teensy/AGENTS.md`](./firmware/teensy/AGENTS.md).
- Understand ISA decode, option ROM placement, or IBM 5155 coexistence: read [`firmware/teensy/IO_PORTS.md`](./firmware/teensy/IO_PORTS.md).
- Use or rebuild the DOS drivers: read [`software/README.md`](./software/README.md).
- Refresh the floppy images: read [`images/README.txt`](./images/README.txt) and run [`scripts/build_xtmax_floppy.py`](./scripts/build_xtmax_floppy.py).
- Work on the Boot ROM SD stack: start with [`software/bootrom/bootrom.asm`](./software/bootrom/bootrom.asm), then regenerate [`firmware/teensy/bootrom.h`](./firmware/teensy/bootrom.h).

## Build And Update Paths

### Teensy firmware

The primary firmware source is [`firmware/teensy/teensy.ino`](./firmware/teensy/teensy.ino).

- Arduino IDE + Teensyduino: open `firmware/teensy/teensy.ino`, select `Teensy 4.1`, and upload.
- Optional CLI: `arduino-cli compile --fqbn teensy:avr:teensy41 firmware/teensy`

### Boot ROM

The Boot ROM source lives in [`software/bootrom/bootrom.asm`](./software/bootrom/bootrom.asm). The firmware consumes the generated header at [`firmware/teensy/bootrom.h`](./firmware/teensy/bootrom.h).

Typical refresh flow from [`software/bootrom`](./software/bootrom):

```bash
nasm -f bin -o bootrom bootrom.asm
python3 checksum.py
python3 generate_header.py
```

### Floppy images

From the repo root:

```bash
pip install -r scripts/requirements-floppy.txt
python3 scripts/build_xtmax_floppy.py
```

This refreshes the driver/data disk images in [`images`](./images).

## Current Constraints

- Hardware validation is still required for firmware, ROM timing, and ISA-bus behavior.
- The repo contains both source files and checked-in generated artifacts such as ROM headers, binaries, floppy images, and PCB fabrication files.
- DOS driver sources are preserved alongside prebuilt binaries for convenience.

## Notes For Maintainers

- If you change SD register behavior or the Boot ROM protocol, update both firmware and ROM artifacts together.
- If you change `MMAN_BASE`, `SD_BASE`, or the ROM mapping assumptions, re-check [`firmware/teensy/IO_PORTS.md`](./firmware/teensy/IO_PORTS.md) and [`software/README.md`](./software/README.md).
- Keep generated cache files out of the repo; root ignore rules cover common Python/macOS noise, but tracked historical artifacts remain as-is.
