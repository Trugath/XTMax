#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

session_root="${XTMAX_MAME_ARTIFACTS_DIR}"
if [[ -n "${XTMAX_MAME_CLEAN_SESSION:-}" ]]; then
  session_root="$(mktemp -d /tmp/xtmax-mame.XXXXXX)"
  trap 'rm -rf "${session_root}"' EXIT
fi

render_mame_config_to "${session_root}"

machine="${MAME_MACHINE:-ibm5155}"
bios="${MAME_BIOS:-}"
seconds="${MAME_SECONDS_TO_RUN:-20}"
xtmax_floppy="${XTMAX_FLOPPY:-${XTMAX_REPO_ROOT}/images/xtmax360.img}"
dos_boot_floppy="${DOS_BOOT_FLOPPY:-}"
autoboot_script="${XTMAX_MAME_AUTObOOT_SCRIPT:-}"
autoboot_command="${XTMAX_MAME_AUTObOOT_COMMAND:-}"
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
  -inipath "${session_root}"
  -rompath "$(combined_rompath)"
  "${machine}"
  -seconds_to_run "${seconds}"
)

if [[ -n "${bios}" ]]; then
  cmd+=( -bios "${bios}" )
fi

if [[ -n "${XTMAX_MAME_DISABLE_ISA4_HDC:-}" ]]; then
  cmd+=( -isa4 "" )
fi

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
  if [[ -n "${autoboot_script}" || -n "${autoboot_command}" ]]; then
    cmd+=( -autoboot_delay "${autoboot_delay}" )
  fi

  if [[ -n "${autoboot_command}" ]]; then
    cmd+=( -autoboot_command "${autoboot_command}" )
  fi

  if [[ -n "${autoboot_script}" ]]; then
    if [[ ! -f "${autoboot_script}" ]]; then
      echo "MAME autoboot script not found: ${autoboot_script}" >&2
      exit 1
    fi
    cmd+=(-autoboot_script "${autoboot_script}")
  fi
else
  cmd+=(-flop1 "${xtmax_floppy}")
fi

echo "Running ${machine} with MAME."
"${cmd[@]}"
