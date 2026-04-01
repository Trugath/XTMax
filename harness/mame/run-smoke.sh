#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

render_mame_config

machine="${MAME_MACHINE:-ibm5155}"
seconds="${MAME_SECONDS_TO_RUN:-20}"
xtmax_floppy="${XTMAX_FLOPPY:-${XTMAX_REPO_ROOT}/images/xtmax360.img}"
dos_boot_floppy="${DOS_BOOT_FLOPPY:-}"
mame_bin="$(find_mame_bin || true)"

if [[ -z "${mame_bin}" ]]; then
  echo "MAME was not found. Run ./harness/mame/bootstrap.sh first or set MAME_BIN." >&2
  exit 1
fi

if [[ ! -f "${xtmax_floppy}" ]]; then
  echo "XTMax floppy image not found: ${xtmax_floppy}" >&2
  exit 1
fi

require_machine_rom "${machine}"

cmd=(
  "${mame_bin}"
  -inipath "${XTMAX_MAME_ARTIFACTS_DIR}"
  -rompath "$(combined_rompath)"
  -seconds_to_run "${seconds}"
  "${machine}"
)

if [[ -n "${dos_boot_floppy}" ]]; then
  if [[ ! -f "${dos_boot_floppy}" ]]; then
    echo "DOS boot floppy not found: ${dos_boot_floppy}" >&2
    exit 1
  fi

  cmd+=(
    -flop1 "${dos_boot_floppy}"
    -flop2 "${xtmax_floppy}"
  )

  autoboot_delay="${MAME_AUTObOOT_DELAY:-8}"
  autoboot_command="${XTMAX_MAME_AUTObOOT_COMMAND:-$'B:\rDIR\r'}"
  cmd+=(
    -autoboot_delay "${autoboot_delay}"
    -autoboot_command "${autoboot_command}"
  )
else
  cmd+=(-flop1 "${xtmax_floppy}")
fi

echo "Running ${machine} with MAME."
"${cmd[@]}"
