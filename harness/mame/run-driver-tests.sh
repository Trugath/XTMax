#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

if [[ -z "${DOS_BOOT_FLOPPY:-}" ]]; then
  echo "Set DOS_BOOT_FLOPPY to a bootable DOS floppy image before running driver tests." >&2
  exit 1
fi

mkdir -p "${XTMAX_MAME_ARTIFACTS_DIR}/assertions"

assert_file="${XTMAX_MAME_ARTIFACTS_DIR}/assertions/driver-test.txt"
rm -f "${assert_file}"

export XTMAX_MAME_ASSERT_FILE="${assert_file}"
export XTMAX_MAME_DISABLE_ISA4_HDC="${XTMAX_MAME_DISABLE_ISA4_HDC:-1}"
export XTMAX_MAME_CLEAN_SESSION="${XTMAX_MAME_CLEAN_SESSION:-1}"

driver_flow="${XTMAX_MAME_DRIVER_FLOW:-}"
if [[ -z "${driver_flow}" ]]; then
  if [[ "${MAME_MACHINE:-}" == "ibm5160" ]]; then
    driver_flow="prompt_gated"
  else
    driver_flow="autoboot"
  fi
fi

case "${driver_flow}" in
  prompt_gated)
    export XTMAX_MAME_EXPECT_TEXT="${XTMAX_MAME_EXPECT_TEXT:-XTSD     SYS|XTEMM    EXE|XTUMBS   SYS}"
    export XTMAX_MAME_AUTObOOT_COMMAND=""
    export XTMAX_MAME_AUTObOOT_SCRIPT="${XTMAX_HARNESS_ROOT}/lua/post_and_assert.lua"
    export XTMAX_MAME_POST_WHEN_TEXT="${XTMAX_MAME_POST_WHEN_TEXT:-A:\\>}"
    export XTMAX_MAME_POST_CODED="${XTMAX_MAME_POST_CODED:-B:\\rDIR\\r}"
    export XTMAX_MAME_POST_AFTER="${XTMAX_MAME_POST_AFTER:-0}"
    export MAME_AUTObOOT_DELAY="${MAME_AUTObOOT_DELAY:-1}"
    export XTMAX_MAME_ASSERT_STARTUP_WAIT="${XTMAX_MAME_ASSERT_STARTUP_WAIT:-0}"
    export XTMAX_MAME_ASSERT_TIMEOUT="${XTMAX_MAME_ASSERT_TIMEOUT:-160}"
    export MAME_SECONDS_TO_RUN="${MAME_SECONDS_TO_RUN:-190}"
    ;;
  autoboot)
    export XTMAX_MAME_EXPECT_TEXT="${XTMAX_MAME_EXPECT_TEXT:-B>|XTSD.SYS|XTEMM.EXE|XTUMBS.SYS}"
    export XTMAX_MAME_AUTObOOT_COMMAND="${XTMAX_MAME_AUTObOOT_COMMAND:-$'B:\rDIR\r'}"
    export XTMAX_MAME_AUTObOOT_SCRIPT="${XTMAX_HARNESS_ROOT}/lua/assert_textmode_dir.lua"
    export MAME_AUTObOOT_DELAY="${MAME_AUTObOOT_DELAY:-30}"
    export XTMAX_MAME_ASSERT_STARTUP_WAIT="${XTMAX_MAME_ASSERT_STARTUP_WAIT:-20}"
    export XTMAX_MAME_ASSERT_TIMEOUT="${XTMAX_MAME_ASSERT_TIMEOUT:-30}"
    export MAME_SECONDS_TO_RUN="${MAME_SECONDS_TO_RUN:-90}"
    ;;
  *)
    echo "Unsupported XTMAX_MAME_DRIVER_FLOW: ${driver_flow}" >&2
    exit 1
    ;;
esac

"${XTMAX_HARNESS_ROOT}/run-smoke.sh"

if [[ ! -f "${assert_file}" ]]; then
  echo "MAME driver test did not produce an assertion result file: ${assert_file}" >&2
  exit 1
fi

if ! grep -qx 'PASS' "${assert_file}"; then
  echo "MAME driver test assertions failed. See ${assert_file}." >&2
  cat "${assert_file}" >&2
  exit 1
fi

echo "MAME driver test assertions passed."
