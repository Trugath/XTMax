#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

machine="${MAME_MACHINE:-ibm5155}"

render_mame_config

if ! required_files_for_machine "${machine}" >/dev/null 2>&1; then
  echo "No ROM checklist is defined for machine ${machine}." >&2
  exit 1
fi

echo "ROM preflight for ${machine}:"
echo

missing=0
while IFS= read -r filename; do
  if path="$(find_rom_file "${filename}" 2>/dev/null)"; then
    echo "  OK      ${filename} -> ${path}"
  else
    echo "  MISSING ${filename}"
    missing=1
  fi
done < <(required_files_for_machine "${machine}")

echo
if [[ "${missing}" -ne 0 ]]; then
  echo "Known source hints:"
  echo "  1501512.u18 / 5000027.u19: https://minuszerodegrees.net/bios/bios.htm"
  echo "  5788005.u33: https://minuszerodegrees.net/rom/rom.htm"
  echo "  14166.bin: https://minuszerodegrees.net/rom/rom.htm"
  echo "  wdbios.rom: supply a MAME-compatible WD controller BIOS under that exact name"
  exit 1
fi

echo "All known required ROM files for ${machine} are present."
