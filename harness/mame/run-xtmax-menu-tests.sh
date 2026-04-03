#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

menu_image="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-menu.img"
build_xtmax_service_image "${menu_image}"

echo "Running XTMax ROM service-loader path."
XTMAX_MAME_SD_IMAGE="${menu_image}" \
XTMAX_MAME_ASSERT_SCRIPT="${XTMAX_HARNESS_ROOT}/lua/post_and_assert.lua" \
XTMAX_MAME_EXPECT_TEXT="XTMAX SERVICE TOOL|S  BOOT FROM XTMAX SD NOW|C  CONTINUE NORMAL BOOTROM FLOW|XTMAX TEST BOOT" \
XTMAX_MAME_POST_WHEN_TEXT="X" \
XTMAX_MAME_POST_CODED="x" \
XTMAX_MAME_POST2_WHEN_TEXT="C  CONTINUE NORMAL BOOTROM FLOW" \
XTMAX_MAME_POST2_CODED="c" \
XTMAX_MAME_ASSERT_STARTUP_WAIT="${XTMAX_MAME_MENU_ASSERT_STARTUP_WAIT:-25}" \
XTMAX_MAME_ASSERT_TIMEOUT="${XTMAX_MAME_MENU_ASSERT_TIMEOUT:-40}" \
./harness/mame/run-xtmax-device-tests.sh

echo "XTMax ROM service-loader test passed."
