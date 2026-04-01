#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

skip_install=0
if [[ "${1:-}" == "--skip-install" ]]; then
  skip_install=1
fi

if [[ "${skip_install}" -eq 0 ]]; then
  install_mame
fi

render_mame_config

echo "MAME harness initialized."
if find_mame_bin >/dev/null 2>&1; then
  echo "MAME binary: $(find_mame_bin)"
else
  echo "MAME binary: not found"
fi
echo "Local config: ${XTMAX_MAME_CONFIG_FILE}"
echo "ROM path: ${XTMAX_MAME_ROMS_DIR}"
echo
echo "Next steps:"
echo "  1. Put a ROM zip like ibm5160.zip or ibm5150.zip in ${XTMAX_MAME_ROMS_DIR}"
echo "  2. Run ./harness/mame/run-smoke.sh"
echo "  3. For DOS automation, set DOS_BOOT_FLOPPY=/path/to/dos-boot.img and run ./harness/mame/run-driver-tests.sh"
