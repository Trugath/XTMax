#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ems_image="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-ems.img"

build_xtmax_ems_boot_image "${ems_image}"

echo "Running XTMax EMS page-frame test."
XTMAX_MAME_SD_IMAGE="${ems_image}" \
XTMAX_MAME_EXPECT_TEXT="XTMAX EMS OK" \
./harness/mame/run-xtmax-device-tests.sh

echo "XTMax EMS page-frame test passed."
