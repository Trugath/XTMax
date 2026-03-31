# XTMax I/O map and IBM 5155 coexistence

## Option ROM disabled (`XTMAX_DISABLE_BOOTROM_MAP`)

If the machine **hangs or the screen goes blank right after the RAM test**, the BIOS may be executing the XTMax **option ROM** before DOS. **Default in this tree is `1`:** the Teensy does **not** map `0xCE000` or the trailing SD page unless you set **`XTMAX_DISABLE_BOOTROM_MAP` to `0`**. Reflash after changing. For SD without ROM, use **`XTSD.SYS`**. If problems persist, try **`XTMAX_SKIP_PSRAM_INIT` = `1`**. See [AGENTS.md](AGENTS.md).

## XTMax firmware decode (fixed in `XTMax.ino`)

| Range | Purpose |
|-------|---------|
| `0x260`–`0x26F` | Memory manager (EMS frame pointers, EMS base, UMB commit). `MMAN_BASE` must stay a multiple of 16. |
| `0x280`–`0x287` | SD card bit-bang registers (`SD_BASE` multiple of 8). Boot ROM in `bootrom.h` uses these ports. |
| Option ROM | `BOOTROM_ADDR` `0xCE000` (see `bootrom.h`). |

If you change `MMAN_BASE` or `SD_BASE`, update both the Teensy sketch **and** regenerate `bootrom.h` from matching option-ROM source.

## IBM 5155 notes

- **Slots:** Only some slots are full-length (13"); use a slot that fits the XTMax PCB mechanically.
- **CPU:** 4.77 MHz typical; autodetect and PSRAM/SD timing constants in `XTMax.ino` are the knobs if cycles are marginal.

## AST SixPakPlus (typical)

Per AST documentation and third-party configuration guides, the SixPakPlus **jumper-selected** functions are **serial** (e.g. COM at `0x3F8` / `0x2F8` / …), **parallel** (`0x378` / `0x278`), **game**, and **clock** — **not** the `0x260` / `0x280` ranges used by XTMax.

**Still verify** on your card: if any other expansion adapter (network, prototype, or custom decode) uses `0x260`–`0x26F` or `0x280`–`0x287`, resolve the conflict (different card jumper, different XTMax bases + rebuilt boot ROM, or move the other card).

## Conventional memory (IBM 5155 + 640 KB on planar / SixPakPlus)

- **Default (`XTMAX_DISABLE_CONVENTIONAL_RAM_MAP` = 1):** `memmap` marks 0–640 KB as **Unused** so XTMax **never** handles those memory cycles. Use this when the motherboard + expansion (e.g. SixPakPlus) provide all conventional RAM. Otherwise the BIOS RAM test can mis-count (e.g. **192K OK** instead of **640K**) because XTMax briefly participates or shadows RAM during POST.
- **Legacy (`XTMAX_DISABLE_CONVENTIONAL_RAM_MAP` = 0):** `memmap` uses `Ram` + **AutoDetect** per 64 KB so XTMax can fill missing conventional RAM; only use if the machine does not have full conventional RAM on the planar/cards.

## Quick conflict checklist

- [ ] No other device decodes `0x260`–`0x26F`.
- [ ] No other device decodes `0x280`–`0x287`.
- [ ] No option ROM overlap at `0xCE000`–`0xCFFFF` for a second card.
- [ ] SixPakPlus jumpers documented for COM/LPT so they do not overlap required motherboard ports.
