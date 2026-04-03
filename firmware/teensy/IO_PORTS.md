# XTMax I/O map and IBM 5155 coexistence

## Option ROM disabled (`XTMAX_DISABLE_BOOTROM_MAP`)

If the machine **hangs or the screen goes blank right after the RAM test**, the BIOS may be executing the XTMax **option ROM** before DOS. Set **`XTMAX_DISABLE_BOOTROM_MAP` to `1`** to keep the Teensy from mapping `0xCE000` or the trailing SD page, then reflash. For SD without ROM, use **`XTSD.SYS`**. If problems persist, try **`XTMAX_SKIP_PSRAM_INIT` = `1`**. See [AGENTS.md](AGENTS.md).

## XTMax firmware decode (fixed in `teensy.ino`)

| Range | Purpose |
|-------|---------|
| `0x260`–`0x26F` | Memory manager (EMS frame pointers, EMS base, UMB commit). `MMAN_BASE` must stay a multiple of 16. |
| `0x280`–`0x287` | SD card bit-bang registers (`SD_BASE` multiple of 8). Boot ROM in `bootrom.h` uses these ports. |
| `0x290`–`0x297` | Auxiliary remote-control registers for host link state, keyboard event queue, and mirror status. |
| `0x298` | **ROM dump data (write):** each `OUT` pushes one byte into a FIFO streamed to the host over USB as lines `Z` + hex + CRLF (requires **DTR high** / host connected). |
| `0x299` | **ROM dump status (read):** returns free FIFO space (0–255); DOS helper should throttle until this is at least ~16 before each burst. |
| `0x29A` | **ROM dump flush (write):** any write drains the FIFO to USB and sends a `ZEND` CRLF line so the host knows the region finished. |
| Option ROM | `BOOTROM_ADDR` `0xCE000` (see `bootrom.h`). |

If you change `MMAN_BASE` or `SD_BASE`, update both the Teensy sketch **and** regenerate `bootrom.h` from matching option-ROM source. If you change the auxiliary block or the `0x298`–`0x29A` dump FIFO, keep the host tool [scripts/mame_roms_via_teensy.py](../../scripts/mame_roms_via_teensy.py) and [software/tools/mameromd.asm](../../software/tools/mameromd.asm) in sync.

The Teensy cannot read the ISA bus on its own: **ROM dumping requires a DOS program on the XT** to read shadowed ROM from memory and `OUT` each byte to `0x298`.

## IBM 5155 notes

- **Slots:** Only some slots are full-length (13"); use a slot that fits the XTMax PCB mechanically.
- **CPU:** 4.77 MHz typical; autodetect and PSRAM/SD timing constants in `teensy.ino` are the knobs if cycles are marginal.

## AST SixPakPlus (typical)

Per AST documentation and third-party configuration guides, the SixPakPlus **jumper-selected** functions are **serial** (e.g. COM at `0x3F8` / `0x2F8` / …), **parallel** (`0x378` / `0x278`), **game**, and **clock** — **not** the `0x260` / `0x280` / `0x290` ranges used by XTMax.

**Still verify** on your card: if any other expansion adapter (network, prototype, or custom decode) uses `0x260`–`0x26F`, `0x280`–`0x287`, or `0x290`–`0x297`, resolve the conflict (different card jumper, different XTMax bases + rebuilt boot ROM, or move the other card).

## Conventional memory (IBM 5155 + 640 KB on planar / SixPakPlus)

- **Default (`XTMAX_DISABLE_CONVENTIONAL_RAM_MAP` = 1):** `memmap` marks 0–640 KB as **Unused** so XTMax **never** handles those memory cycles. Use this when the motherboard + expansion (e.g. SixPakPlus) provide all conventional RAM. Otherwise the BIOS RAM test can mis-count (e.g. **192K OK** instead of **640K**) because XTMax briefly participates or shadows RAM during POST.
- **Legacy (`XTMAX_DISABLE_CONVENTIONAL_RAM_MAP` = 0):** `memmap` uses `Ram` + **AutoDetect** per 64 KB so XTMax can fill missing conventional RAM; only use if the machine does not have full conventional RAM on the planar/cards.

## Quick conflict checklist

- [ ] No other device decodes `0x260`–`0x26F`.
- [ ] No other device decodes `0x280`–`0x287`.
- [ ] No other device decodes `0x290`–`0x297`.
- [ ] No other device decodes `0x298`–`0x29F` (ROM dump FIFO).
- [ ] No option ROM overlap at `0xCE000`–`0xCFFFF` for a second card.
- [ ] SixPakPlus jumpers documented for COM/LPT so they do not overlap required motherboard ports.
