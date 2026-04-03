# XTMax Teensy Firmware Guide

This directory contains the primary Teensy 4.1 firmware source and the generated Boot ROM artifacts consumed by that firmware.

## Primary Files

- [teensy.ino](./teensy.ino): main hardware-facing firmware
- [xtmax_core.h](./xtmax_core.h) and [xtmax_core.cpp](./xtmax_core.cpp): shared XT-visible state and decode logic
- [bootrom.h](./bootrom.h): generated header consumed by the sketch
- [bootrom.bin](./bootrom.bin): generated ROM binary artifact
- [IO_PORTS.md](./IO_PORTS.md): decode map, coexistence notes, and AUX/MMAN/SD port assignments

## Build

From the repository root:

```bash
arduino-cli compile --fqbn teensy:avr:teensy41 firmware/teensy
```

You can also open [teensy.ino](./teensy.ino) in Arduino IDE with Teensyduino and select `Teensy 4.1`.

## If You Edit Specific Areas

### Boot ROM interaction

If you change SD register behavior, Boot ROM protocol, ROM mapping, or service-loader assumptions:

1. update [software/bootrom/bootrom.asm](../../software/bootrom/bootrom.asm) as needed
2. regenerate [bootrom.bin](./bootrom.bin) and [bootrom.h](./bootrom.h)
3. rerun the host-side and MAME regressions that cover Boot ROM behavior

### Shared host-link / AUX block

If you change the AUX block at `0x290-0x297`, update and re-check all of:

- [xtmax_core.cpp](./xtmax_core.cpp)
- [teensy.ino](./teensy.ino)
- [host/xtmax-host](../../host/xtmax-host)
- [harness/mame/patches/0001-add-xtmax-phase1-card.patch](../../harness/mame/patches/0001-add-xtmax-phase1-card.patch)

### Memory map / MMAN

If you change `MMAN_BASE`, `SD_BASE`, `AUX_BASE`, ROM placement, or conventional-memory mapping assumptions, re-check [IO_PORTS.md](./IO_PORTS.md) and the DOS-driver notes in [software/README.md](../../software/README.md).

## Useful Verification

### Fast local checks

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
arduino-cli compile --fqbn teensy:avr:teensy41 firmware/teensy
```

### XT-visible regression checks in MAME

These validate the emulated XTMax device model, not the real Teensy timing path:

```bash
./harness/mame/run-xtmax-bootrom-tests.sh
./harness/mame/run-xtmax-storage-tests.sh
./harness/mame/run-xtmax-ems-tests.sh
./harness/mame/run-xtmax-menu-tests.sh
./harness/mame/run-xtmax-mirror-tests.sh
```

## Hardware Bring-Up Notes

### Blank screen or hang right after RAM test

1. Set `XTMAX_DISABLE_BOOTROM_MAP` to `1` in [teensy.ino](./teensy.ino) so XTMax does not map the option ROM or trailing SD MMIO page.
2. Reflash and retest.
3. If the machine is still unstable, set `XTMAX_SKIP_PSRAM_INIT` to `1` to remove PSRAM init from the boot path.
4. If conventional memory is already fully provided by the motherboard and other cards, keep `XTMAX_DISABLE_CONVENTIONAL_RAM_MAP` at `1`.
5. For SD access without the ROM, use `XTSD.SYS` from floppy.

### IBM 5155 / similar XT-class systems

- Mechanical fit still matters; use a slot that actually accommodates the XTMax PCB.
- 4.77 MHz timing margins are real. The timing defines near the top of [teensy.ino](./teensy.ino) are the knobs to revisit if SD, EMS, or bus sniffing become marginal.
- The Boot ROM now uses direct text-memory output on the active page. If video trouble returns, treat that as a regression to investigate rather than relying on old `INT 10h` assumptions.

## Important Limits

- Passing MAME regressions does not prove real ISA timing, PSRAM timing, or USB streaming behavior on hardware.
- Passing `arduino-cli compile` does not prove the board works in a real XT.
- This tree contains generated artifacts alongside source. Do not hand-edit generated ROM artifacts unless the task is specifically about the generated file itself.
