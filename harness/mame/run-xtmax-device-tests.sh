#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

session_root="${XTMAX_MAME_ARTIFACTS_DIR}"
if [[ -n "${XTMAX_MAME_CLEAN_SESSION:-1}" ]]; then
  session_root="$(mktemp -d /tmp/xtmax-mame-device.XXXXXX)"
  trap 'rm -rf "${session_root}"' EXIT
fi

render_mame_config_to "${session_root}"
stage_xtmax_device_bootrom

machine="${MAME_MACHINE:-ibm5160}"
bios="${MAME_BIOS:-rev2}"
seconds="${MAME_SECONDS_TO_RUN:-120}"
slot="${XTMAX_MAME_DEVICE_SLOT:-isa5}"
assert_file="${XTMAX_MAME_ARTIFACTS_DIR}/assertions/xtmax-device-test.txt"
patched_bin="$(xtmax_mame_patched_bin)"
assert_script="${XTMAX_MAME_ASSERT_SCRIPT:-${XTMAX_HARNESS_ROOT}/lua/assert_textmode_dir.lua}"

mkdir -p "${XTMAX_MAME_ARTIFACTS_DIR}/assertions"
rm -f "${assert_file}"

if [[ -z "${XTMAX_MAME_NO_SD_IMAGE:-}" ]]; then
  using_default_sd_image=0
  if [[ -z "${XTMAX_MAME_SD_IMAGE:-}" ]]; then
    export XTMAX_MAME_SD_IMAGE="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-sd.img"
    using_default_sd_image=1
  fi

  if [[ "${using_default_sd_image}" -eq 1 && ( -z "${XTMAX_MAME_KEEP_EXISTING_SD_IMAGE:-}" || ! -s "${XTMAX_MAME_SD_IMAGE}" ) ]]; then
    build_xtmax_test_boot_image "${XTMAX_MAME_SD_IMAGE}"
  fi
fi

export XTMAX_MAME_ASSERT_FILE="${assert_file}"
if [[ -n "${XTMAX_MAME_SD_IMAGE:-}" ]]; then
  export XTMAX_MAME_EXPECT_TEXT="${XTMAX_MAME_EXPECT_TEXT:-XTMAX TEST BOOT}"
else
  export XTMAX_MAME_EXPECT_TEXT="${XTMAX_MAME_EXPECT_TEXT:-XTMAX BOOTROM|SD CARD FAILED TO INITIALIZE}"
fi
export XTMAX_MAME_EXPECT_CS="${XTMAX_MAME_EXPECT_CS:-}"
export XTMAX_MAME_EXPECT_IP="${XTMAX_MAME_EXPECT_IP:-}"
export XTMAX_MAME_EXPECT_HALT="${XTMAX_MAME_EXPECT_HALT:-}"
export XTMAX_MAME_POST_AFTER="${XTMAX_MAME_POST_AFTER:-0}"
export XTMAX_MAME_POST_CODED="${XTMAX_MAME_POST_CODED:-}"
export XTMAX_MAME_POST_WHEN_TEXT="${XTMAX_MAME_POST_WHEN_TEXT:-}"
export XTMAX_MAME_ASSERT_STARTUP_WAIT="${XTMAX_MAME_ASSERT_STARTUP_WAIT:-25}"
export XTMAX_MAME_ASSERT_TIMEOUT="${XTMAX_MAME_ASSERT_TIMEOUT:-75}"

if [[ -n "${XTMAX_MAME_USE_SYSTEM_MAME:-}" ]]; then
  mame_bin="$(find_mame_bin || true)"
else
  mame_bin="${patched_bin}"
fi

if [[ -z "${mame_bin}" || ! -x "${mame_bin}" ]]; then
  echo "Patched MAME was not found at ${patched_bin}" >&2
  echo "Run ./harness/mame/build-mame-xtmax.sh first, or set XTMAX_MAME_USE_SYSTEM_MAME=1 with a compatible custom build." >&2
  exit 1
fi

require_machine_rom "${machine}"

cmd=(
  "${mame_bin}"
  -inipath "${session_root}"
  -rompath "$(combined_rompath)"
  "${machine}"
  -bios "${bios}"
  -seconds_to_run "${seconds}"
  -autoboot_script "${assert_script}"
  -isa4 ""
  "-${slot}" xtmax
)

echo "Running ${machine} with XTMax phase-1 device in ${slot}."
"${cmd[@]}"

if [[ ! -f "${assert_file}" ]]; then
  echo "XTMax device test did not produce an assertion result file: ${assert_file}" >&2
  exit 1
fi

if ! grep -qx 'PASS' "${assert_file}"; then
  echo "XTMax device test assertions failed. See ${assert_file}." >&2
  cat "${assert_file}" >&2
  exit 1
fi

echo "XTMax device test assertions passed."
