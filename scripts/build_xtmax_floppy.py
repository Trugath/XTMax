#!/usr/bin/env python3
"""
Build a FAT12 MS-DOS floppy disk image (.img) for XTMax:
  - Official drivers from MicroCoreLabs GitHub (XTSD, XTEMM, XTUMBS, TEST!UMB)
  - CONFIG.SYS / README.TXT with usage notes

Requires: pip install -r requirements-floppy.txt
"""
from __future__ import annotations

import argparse
import os
import sys
import urllib.error
import urllib.request

from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS

# Raw files from MicroCoreLabs Projects tree (same binaries described in software/README.md)
DRIVER_BASE = (
    "https://raw.githubusercontent.com/MicroCoreLabs/Projects/master/XTMax/Drivers/"
)
DOWNLOADS: list[tuple[str, str]] = [
    ("XTSD.SYS", "XTSD.SYS"),
    ("XTEMM.EXE", "XTEMM.EXE"),
    ("XTUMBS.SYS", "XTUMBS.SYS"),
    ("TEST!UMB.EXE", "TEST!UMB.EXE"),
]

SIZES_K = {
    360: 368640,   # 40*2*9*512
    720: 737280,   # 80*2*9*512
}

FLOPPY_BPB = {
    360: {
        "media_descriptor": 0xFD,
        "sectors_per_track": 9,
        "heads": 2,
    },
    720: {
        "media_descriptor": 0xF9,
        "sectors_per_track": 9,
        "heads": 2,
    },
}

README_TXT = """\
XTMax floppy - MS-DOS drivers and notes
========================================

NOTE: This floppy image is not DOS-bootable by default.
To make it bootable on a DOS machine, run: SYS A:

Files on this disk:
  XTSD.SYS     SD card (parallel-port style) if BIOS option ROM does NOT run
  XTEMM.EXE    LIM 4.0 EMS (PSRAM on Teensy)
  XTUMBS.SYS   Upper Memory Blocks in 0xA0000-0xEFFFF
  TEST!UMB.EXE UMB test (see software/README.md)

CONFIG.SYS
----------
Edit CONFIG.SYS on this disk. Uncomment ONE strategy at a time.

- If the XTMax option ROM at 0xCE000 loads and you use INT 13h for the SD,
  you usually do NOT need XTSD.SYS.
- If you do use XTSD.SYS, prefer FAT16 partitions <= 32 MB for compatibility.
- You can force the partition with: DEVICE=A:\\XTSD.SYS /P=1

- EMS: DEVICE=A:\\XTEMM.EXE /N
  Optional page frame: /P:E000 for segment E000 (0xE0000-0xEFFFF)

- UMBs: DEVICE=A:\\XTUMBS.SYS D000-E000
  Avoid overlap with video RAM, ROMs, or EMS window.

Full documentation:
  ..\\software\\README.md (in the XTMax repository)

IBM 5155 / I/O:
  See firmware\\XTMax\\IO_PORTS.md (MMAN 0x260, SD 0x280-0x287).
""".replace("\n", "\r\n").encode("cp437", errors="replace")

CONFIG_SYS = b"""\
REM XTMax - uncomment drivers after reading A:\\README.TXT
REM SD without option ROM:
REM DEVICE=A:\\XTSD.SYS
REM EMS (LIM 4.0):
REM DEVICE=A:\\XTEMM.EXE /N
REM UMBs (no overlap with EMS/video):
REM DEVICE=A:\\XTUMBS.SYS D000-E000
FILES=20
BUFFERS=20
LASTDRIVE=Z
"""

AUTOEXEC_BAT = b"""\
@echo off
echo XTMax driver disk - type README.TXT for help.
"""


def fetch(base: str, path_tail: str, dest_path: str) -> None:
    from urllib.parse import quote

    url = base + quote(path_tail, safe="")
    print(f"  fetching {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "xtmax-floppy-build"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    with open(dest_path, "wb") as f:
        f.write(data)
    print(f"    -> {len(data)} bytes")


def build_image(out_path: str, size_bytes: int, staging_dir: str, skip_download: bool) -> None:
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    os.makedirs(staging_dir, exist_ok=True)

    if not skip_download:
        for url_name, save_name in DOWNLOADS:
            try:
                fetch(DRIVER_BASE, url_name, os.path.join(staging_dir, save_name))
            except (OSError, urllib.error.HTTPError) as e:
                print(f"  WARN: could not download {save_name}: {e}", file=sys.stderr)
    else:
        for _, save_name in DOWNLOADS:
            p = os.path.join(staging_dir, save_name)
            if not os.path.isfile(p):
                print(f"Missing {p} (use download or copy drivers here)", file=sys.stderr)
                sys.exit(1)

    if os.path.exists(out_path):
        os.remove(out_path)
    with open(out_path, "wb") as f:
        f.write(b"\x00" * size_bytes)

    pf = PyFat()
    pf.mkfs(out_path, PyFat.FAT_TYPE_FAT12, size=size_bytes, label="XTMAX")
    pf.close()
    _patch_floppy_bpb(out_path, size_bytes)

    fs = PyFatFS(out_path, read_only=False)
    try:
        fs.writebytes("/README.TXT", README_TXT)
        fs.writebytes("/CONFIG.SYS", CONFIG_SYS)
        fs.writebytes("/AUTOEXEC.BAT", AUTOEXEC_BAT)
        for _, save_name in DOWNLOADS:
            src = os.path.join(staging_dir, save_name)
            if not os.path.isfile(src):
                print(f"  skip (missing): {save_name}", file=sys.stderr)
                continue
            with open(src, "rb") as f:
                data = f.read()
            dest = "/" + save_name.upper()
            fs.writebytes(dest, data)
    finally:
        fs.close()

    print(f"Wrote {out_path} ({size_bytes} bytes)")


def _patch_floppy_bpb(out_path: str, size_bytes: int) -> None:
    size_k = size_bytes // 1024
    if size_k not in FLOPPY_BPB:
        return

    geom = FLOPPY_BPB[size_k]
    with open(out_path, "r+b") as f:
        # FAT BPB offsets in boot sector.
        f.seek(21)
        f.write(bytes([geom["media_descriptor"]]))
        f.seek(24)
        f.write(int(geom["sectors_per_track"]).to_bytes(2, "little"))
        f.seek(26)
        f.write(int(geom["heads"]).to_bytes(2, "little"))


def main() -> None:
    ap = argparse.ArgumentParser(description="Build XTMax MS-DOS floppy .img")
    ap.add_argument(
        "-o",
        "--output",
        default=os.path.join(
            os.path.dirname(__file__), "..", "images", "xtmax360.img"
        ),
        help="Output .img path",
    )
    ap.add_argument(
        "--size",
        type=int,
        choices=(360, 720),
        default=360,
        help="Floppy capacity (KiB); default 360 (5.25 DD / common Gotek)",
    )
    ap.add_argument(
        "--staging",
        default=os.path.join(os.path.dirname(__file__), "_driver_staging"),
        help="Temp dir for downloaded drivers",
    )
    ap.add_argument(
        "--no-download",
        action="store_true",
        help="Use drivers already present in staging dir",
    )
    args = ap.parse_args()

    out_path = os.path.normpath(args.output)
    size_bytes = SIZES_K[args.size]
    build_image(out_path, size_bytes, args.staging, args.no_download)


if __name__ == "__main__":
    main()
