#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

rw_image="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-storage-rw.img"

build_xtmax_rw_boot_image "${rw_image}"

echo "Running XTMax storage read/write path."
XTMAX_MAME_SD_IMAGE="${rw_image}" \
XTMAX_MAME_EXPECT_TEXT="XTMAX RW OK" \
./harness/mame/run-xtmax-device-tests.sh

echo "XTMax storage read/write test passed."
