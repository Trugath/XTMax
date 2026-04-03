#!/usr/bin/env python3
"""
Capture PC ROM images over the Teensy USB serial link (XTMax dump FIFO at 0x298–0x29A).

The Teensy does not read the ISA bus by itself: you must run the DOS helper
MROMD.COM on the XT (see software/tools/mameromd.asm) for each region while
this script listens on the host.

Legal: only dump ROMs you own or may lawfully copy for personal backup / emulation.
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import time
from typing import Any

try:
    import serial  # type: ignore
except ImportError as exc:  # pragma: no cover
    print(
        "pyserial is required: pip install -r scripts/requirements-mame-romdump.txt",
        file=sys.stderr,
    )
    raise SystemExit(1) from exc


# Regions aligned with harness/mame/common.sh stage_known_rom_aliases() layout.
# BIOS U18/U19 order may need swapping on some boards — if MAME rejects checksums,
# exchange the two 32 KB files or adjust segment/offset in a custom profile.
PROFILES: dict[str, list[dict[str, Any]]] = {
    "ibm5160-harness": [
        {
            "relpath": "ibm5160/1501512.u18",
            "seg": 0xF000,
            "off": 0x0000,
            "len": 0x8000,
        },
        {
            "relpath": "ibm5160/5000027.u19",
            "seg": 0xF000,
            "off": 0x8000,
            "len": 0x8000,
        },
        {
            "relpath": "cga/5788005.u33",
            "seg": 0xC000,
            "off": 0x0000,
            "len": 0x0800,
        },
        {
            "relpath": "isa_hdc/wdbios.rom",
            "seg": 0xC800,
            "off": 0x0000,
            "len": 0x4000,
        },
        {
            "skip": True,
            "relpath": "keytronic_pc3270/14166.bin",
            "note": "Keyboard MCU firmware is not in the ISA memory map; obtain 14166.bin from your MAME/legal ROM set.",
        },
    ],
}


def decode_z_payload(line: str) -> bytes | None:
    if not line.startswith("Z") or line.startswith("ZEND"):
        return None
    body = line[1:]
    if len(body) % 2 != 0:
        raise ValueError(f"odd-length hex payload: {line!r}")
    return bytes.fromhex(body)


def read_region(
    ser: serial.Serial,
    expected_len: int,
    idle_timeout_s: float,
    overall_timeout_s: float,
) -> bytes:
    buf = bytearray()
    last_data = time.monotonic()
    deadline = time.monotonic() + overall_timeout_s

    while time.monotonic() < deadline:
        if ser.in_waiting:
            raw = ser.readline()
            try:
                line = raw.decode("ascii", errors="replace").strip()
            except Exception:
                continue
            last_data = time.monotonic()

            if line == "ZEND":
                break
            if line.startswith("VM ") or line.startswith("VI "):
                continue
            if not line.startswith("Z"):
                continue
            chunk = decode_z_payload(line)
            if chunk:
                buf.extend(chunk)
                if len(buf) >= expected_len:
                    break
        else:
            if buf and (time.monotonic() - last_data) > idle_timeout_s:
                break
            time.sleep(0.02)

    return bytes(buf)


def cmd_listen(args: argparse.Namespace) -> int:
    out = pathlib.Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    profile = PROFILES[args.profile]
    ser = serial.Serial(
        port=args.port,
        baudrate=args.baud,
        timeout=0.1,
    )
    ser.dtr = True
    ser.rts = True
    time.sleep(0.2)

    for entry in profile:
        if entry.get("skip"):
            note = entry.get("note", "")
            print(f"Skipping {entry.get('relpath', '?')}: {note}")
            continue

        rel = entry["relpath"]
        seg = int(entry["seg"])
        off = int(entry["off"])
        length = int(entry["len"])
        dest = out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)

        cmd = f"MROMD.COM {seg:04X} {off:04X} {length:04X}"
        print()
        print(f"--- Next file: {rel} ({length} bytes) ---")
        print(f"    On the XT, run:  {cmd}")
        if args.auto:
            print("    Auto mode: listening (Ctrl-C to abort)...")
            time.sleep(2.0)
        else:
            print(
                "    Press Enter on this host when you are ready, then run MROMD on the XT.",
            )
            input()

        ser.reset_input_buffer()
        t0 = time.monotonic()
        data = read_region(
            ser,
            expected_len=length,
            idle_timeout_s=args.idle_timeout,
            overall_timeout_s=args.overall_timeout,
        )
        if args.auto and len(data) < length:
            print(
                f"Warning: got {len(data)} bytes in {time.monotonic() - t0:.1f}s, expected {length}",
                file=sys.stderr,
            )
        dest.write_bytes(data[:length] if len(data) >= length else data)
        print(f"Wrote {dest} ({dest.stat().st_size} bytes)")

    ser.close()
    print("\nDone. Point MAME rompath at this directory or merge into harness/mame/roms/.")
    return 0


def cmd_list(_args: argparse.Namespace) -> int:
    for name in sorted(PROFILES):
        print(name)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Collect MAME-oriented ROM dumps from an XT via XTMax USB + MROMD.COM",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_listen = sub.add_parser("listen", help="Guided capture for a profile (serial listener)")
    p_listen.add_argument("--port", required=True, help="Serial device (e.g. /dev/ttyACM0)")
    p_listen.add_argument("--baud", type=int, default=115_200)
    p_listen.add_argument(
        "--out",
        default="harness/mame/roms",
        help="Output root (mirrors ibm5160/, cga/, ... subdirs)",
    )
    p_listen.add_argument(
        "--profile",
        default="ibm5160-harness",
        help="Region set name (see list-profiles)",
    )
    p_listen.add_argument(
        "--auto",
        action="store_true",
        help="Do not prompt; wait for ZEND / idle timeout between instructions",
    )
    p_listen.add_argument(
        "--idle-timeout",
        type=float,
        default=3.0,
        help="Seconds with no serial lines before ending a region (auto mode)",
    )
    p_listen.add_argument(
        "--overall-timeout",
        type=float,
        default=300.0,
        help="Max seconds per region",
    )
    p_listen.set_defaults(func=cmd_listen)

    p_list = sub.add_parser("list-profiles", help="Print profile names")
    p_list.set_defaults(func=cmd_list)

    args = parser.parse_args()
    if args.command == "listen" and args.profile not in PROFILES:
        print(f"Unknown profile {args.profile!r}. Use: list-profiles", file=sys.stderr)
        return 2
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
