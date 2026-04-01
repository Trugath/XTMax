# Repo Layout

This repository mixes source code, generated artifacts, third-party legacy toolchains, and ready-to-use binaries. The goal of this guide is to make it clear which files are the primary things to edit.

## Primary Sources

- [`firmware/teensy/XTMax.ino`](../firmware/teensy/XTMax.ino): main Teensy 4.1 firmware.
- [`software/bootrom/bootrom.asm`](../software/bootrom/bootrom.asm): BIOS extension ROM source for SD boot and INT 13h services.
- [`software/sd`](../software/sd): DOS SD driver source used for `XTSD.SYS`.
- [`software/emm`](../software/emm): EMS driver source used for `XTEMM.EXE`.
- [`software/umb`](../software/umb): UMB driver source used for `XTUMBS.SYS` and `TEST!UMB.EXE`.
- [`hardware/pcb`](../hardware/pcb): KiCad project sources.
- [`scripts/build_xtmax_floppy.py`](../scripts/build_xtmax_floppy.py): floppy image builder.
- [`tests/test_sdcard_stack.py`](../tests/test_sdcard_stack.py): host-side tests.

## Generated Or Derived Artifacts

- [`firmware/teensy/bootrom.h`](../firmware/teensy/bootrom.h): generated from `software/bootrom/bootrom.asm`.
- [`firmware/teensy/bootrom.bin`](../firmware/teensy/bootrom.bin): checked-in binary ROM artifact.
- [`software/bin/XTSD.SYS`](../software/bin/XTSD.SYS), [`software/bin/XTEMM.EXE`](../software/bin/XTEMM.EXE), [`software/bin/XTUMBS.SYS`](../software/bin/XTUMBS.SYS), [`software/bin/TEST!UMB.EXE`](../software/bin/TEST!UMB.EXE): ready-to-use driver binaries.
- [`images/xtmax360.img`](../images/xtmax360.img), [`images/xtmax720.img`](../images/xtmax720.img): generated floppy images.
- [`hardware/fabrication`](../hardware/fabrication): fabrication outputs.

## Reference And Operational Docs

- [`firmware/teensy/AGENTS.md`](../firmware/teensy/AGENTS.md): firmware build/use notes and machine-specific troubleshooting.
- [`firmware/teensy/IO_PORTS.md`](../firmware/teensy/IO_PORTS.md): I/O map and coexistence notes.
- [`software/README.md`](../software/README.md): DOS driver and Boot ROM usage.
- [`images/README.txt`](../images/README.txt): floppy image notes.

## Third-Party / Legacy Build Tooling

- [`software/toolchains`](../software/toolchains): DOS-era compilers, assemblers, and helpers kept in-tree for reproducibility.

## Editing Guidance

- Edit source first, then regenerate derived artifacts in the same change where practical.
- Treat `bootrom.h`, floppy images, and PCB production outputs as outputs, not the canonical source of truth.
- Avoid broad cleanup of tracked historical binaries unless that is the explicit task.
