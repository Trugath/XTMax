# Repo Layout

This repository mixes source code, generated artifacts, third-party legacy toolchains, and ready-to-use binaries. The goal of this guide is to make it clear which files are the primary things to edit.

## Primary Sources

- [`Code/XTMax/XTMax.ino`](../Code/XTMax/XTMax.ino): main Teensy 4.1 firmware.
- [`Drivers/BootROM/bootrom.asm`](../Drivers/BootROM/bootrom.asm): BIOS extension ROM source for SD boot and INT 13h services.
- [`Drivers/SDPP`](../Drivers/SDPP): DOS SD driver source used for `XTSD.SYS`.
- [`Drivers/LTEMM`](../Drivers/LTEMM): EMS driver source used for `XTEMM.EXE`.
- [`Drivers/USEUMB`](../Drivers/USEUMB): UMB driver source used for `XTUMBS.SYS` and `TEST!UMB.EXE`.
- [`PCB/XTMAX_PCB`](../PCB/XTMAX_PCB): KiCad project sources.
- [`scripts/build_xtmax_floppy.py`](../scripts/build_xtmax_floppy.py): floppy image builder.
- [`tests/test_sdcard_stack.py`](../tests/test_sdcard_stack.py): host-side tests.

## Generated Or Derived Artifacts

- [`Code/XTMax/bootrom.h`](../Code/XTMax/bootrom.h): generated from `Drivers/BootROM/bootrom.asm`.
- [`Code/XTMax/bootrom.bin`](../Code/XTMax/bootrom.bin): checked-in binary ROM artifact.
- [`Drivers/XTSD.SYS`](../Drivers/XTSD.SYS), [`Drivers/XTEMM.EXE`](../Drivers/XTEMM.EXE), [`Drivers/XTUMBS.SYS`](../Drivers/XTUMBS.SYS), [`Drivers/TEST!UMB.EXE`](../Drivers/TEST!UMB.EXE): ready-to-use driver binaries.
- [`Floppy/xtmax360.img`](../Floppy/xtmax360.img), [`Floppy/xtmax720.img`](../Floppy/xtmax720.img): generated floppy images.
- [`PCB/XTMAX_PCB/PCB_PRODUCTS`](../PCB/XTMAX_PCB/PCB_PRODUCTS): fabrication outputs.

## Reference And Operational Docs

- [`Code/XTMax/AGENTS.md`](../Code/XTMax/AGENTS.md): firmware build/use notes and machine-specific troubleshooting.
- [`Code/XTMax/IO_PORTS.md`](../Code/XTMax/IO_PORTS.md): I/O map and coexistence notes.
- [`Drivers/README.md`](../Drivers/README.md): DOS driver and Boot ROM usage.
- [`Floppy/README.txt`](../Floppy/README.txt): floppy image notes.

## Third-Party / Legacy Build Tooling

- [`Drivers/Driver_Build_Tools`](../Drivers/Driver_Build_Tools): DOS-era compilers, assemblers, and helpers kept in-tree for reproducibility.

## Editing Guidance

- Edit source first, then regenerate derived artifacts in the same change where practical.
- Treat `bootrom.h`, floppy images, and PCB production outputs as outputs, not the canonical source of truth.
- Avoid broad cleanup of tracked historical binaries unless that is the explicit task.
