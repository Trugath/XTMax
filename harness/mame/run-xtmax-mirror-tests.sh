#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

mirror_log="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-mirror.log"
rendered_text="${XTMAX_MAME_ARTIFACTS_DIR}/assertions/xtmax-mirror-rendered.txt"

mkdir -p "${XTMAX_MAME_ARTIFACTS_DIR}/assertions"
rm -f "${mirror_log}" "${rendered_text}"

echo "Running XTMax MAME mirror capture."
XTMAX_MAME_MIRROR_LOG="${mirror_log}" \
XTMAX_MAME_SD_IMAGE="${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-menu.img" \
./harness/mame/run-xtmax-menu-tests.sh

if [[ ! -s "${mirror_log}" ]]; then
  echo "XTMax mirror test did not produce a mirror log: ${mirror_log}" >&2
  exit 1
fi

cargo run --quiet --manifest-path "${XTMAX_REPO_ROOT}/host/xtmax-host/Cargo.toml" -- \
  render-log "${mirror_log}" > "${rendered_text}"

if ! grep -q "XTMAX SERVICE TOOL" "${rendered_text}"; then
  echo "Rendered mirror output did not include the XTMax service menu." >&2
  cat "${rendered_text}" >&2
  exit 1
fi

if ! grep -q "XTMAX TEST BOOT" "${rendered_text}"; then
  echo "Rendered mirror output did not include the XTMax boot text." >&2
  cat "${rendered_text}" >&2
  exit 1
fi

echo "XTMax mirror test passed."
