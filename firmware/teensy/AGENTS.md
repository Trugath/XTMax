# XTMax (Teensy 4.1)

## Build

- **Arduino IDE** with **Teensyduino** add-on: open `XTMax.ino`, select **Teensy 4.1**, upload.
- **Optional CLI:** `arduino-cli compile --fqbn teensy:avr:teensy41 .` from this directory (requires Teensy board package).

## MS-DOS driver floppy (.img)

From the **XTMax repository root**: run `python scripts/build_xtmax_floppy.py` after `pip install -r scripts/requirements-floppy.txt`. Output: [`images/xtmax360.img`](../../images/xtmax360.img). See [`images/README.txt`](../../images/README.txt).
The generated image is a driver/data disk (not DOS bootable) until system files are installed with `SYS A:`.

## Blank screen after RAM test (hangs before DOS)

1. For machines that blank or hang after the RAM test, set **`XTMAX_DISABLE_BOOTROM_MAP` = `1`** so the Teensy does **not** map the option ROM at `0xCE000` or the trailing SD MMIO page. Reflash after changing it.
2. The option ROM can **clear the screen** and **stall** (SD init) **even with no SD card**. With ROM mapping off, use **`XTSD.SYS`** from floppy for SD.
3. If it is **still** blank, set **`XTMAX_SKIP_PSRAM_INIT` to `1`** (no PSRAM / EMS not needed yet) and reflash — skips quad-SPI PSRAM setup at boot.
4. **Isolate:** boot the 5155 **with XTMax removed**. If the machine still blanks, the fault is not the Teensy sketch (video, RAM, or another card).
5. On IBM 5155-class systems, keep BootROM built with **`QUIET_VIDEO_OUTPUT`** ([`bootrom.asm`](../../software/bootrom/bootrom.asm)) to suppress ROM INT 10h teletype output that can blank the display.

## Performance tuning (firmware)

Timing `#define`s are at the top of `XTMax.ino` (`SD_SPI_BIT_TIME_NS`, `IO_WRITE_SETTLE_NS`, `MUX_DATA_SWITCH_NS`, `PSRAM_CONFIGURE_DELAY_US`, `XTMAX_PSRAM_EARLY_CHRDY`). If **SD/EMS** glitch after changes, increase SPI delay or set `XTMAX_PSRAM_EARLY_CHRDY` to `0`.

## Configuration

- **I/O / coexistence:** [IO_PORTS.md](IO_PORTS.md)
- **Conventional RAM:** default is **`XTMAX_DISABLE_CONVENTIONAL_RAM_MAP` = `1`** so XTMax ignores 0–640 KB (recommended with planar + SixPakPlus). Set to **`0`** only if XTMax must emulate conventional RAM. If POST showed wrong RAM (e.g. 192K vs 640K), keep default `1`.

## Hardware validation (IBM 5155)

1. Install the card in a **full-length** slot if the PCB requires it.
2. Flash firmware, power on: confirm **POST** and **640 KB** conventional memory with CHKDSK / DOS.
3. Confirm option ROM messages if the BIOS scans `0xCE000`.
4. Details: [IO_PORTS.md](IO_PORTS.md).

Automated CI cannot run this firmware; build verification is **Arduino compile success** on your workstation.
