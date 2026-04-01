#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DOS_BOOT_FLOPPY:-}" ]]; then
  echo "Set DOS_BOOT_FLOPPY to a bootable DOS floppy image before running driver tests." >&2
  exit 1
fi

export XTMAX_MAME_AUTObOOT_COMMAND="${XTMAX_MAME_AUTObOOT_COMMAND:-$'B:\rDIR\r'}"

exec "$(cd "$(dirname "$0")" && pwd)/run-smoke.sh"
