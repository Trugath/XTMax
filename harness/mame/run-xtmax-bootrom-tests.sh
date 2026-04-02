#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

success_image="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-bootrom-success.img"
invalid_image="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-bootrom-invalid.img"

build_xtmax_test_boot_image "${success_image}"
build_xtmax_invalid_boot_image "${invalid_image}"

echo "Running XTMax Boot ROM success path."
XTMAX_MAME_SD_IMAGE="${success_image}" \
XTMAX_MAME_EXPECT_TEXT="XTMAX TEST BOOT" \
./harness/mame/run-xtmax-device-tests.sh

echo "Running XTMax Boot ROM invalid-boot path."
XTMAX_MAME_SD_IMAGE="${invalid_image}" \
XTMAX_MAME_EXPECT_TEXT="${XTMAX_MAME_INVALID_EXPECT_TEXT:-NO BOOT MEDIA}" \
XTMAX_MAME_ASSERT_STARTUP_WAIT="${XTMAX_MAME_INVALID_ASSERT_STARTUP_WAIT:-25}" \
XTMAX_MAME_ASSERT_TIMEOUT="${XTMAX_MAME_INVALID_ASSERT_TIMEOUT:-30}" \
./harness/mame/run-xtmax-device-tests.sh

echo "XTMax Boot ROM success and invalid-boot tests passed."
