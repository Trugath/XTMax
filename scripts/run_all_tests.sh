#!/usr/bin/env bash
# Run every automated test that does not require user-supplied media.
# From the repository root:
#   ./scripts/run_all_tests.sh
#
# Optional environment:
#   MAME_SECONDS_TO_RUN   Cap for each patched-MAME invocation (default: 90)
#   MAME_SMOKE_SECONDS    Cap for stock run-smoke.sh (default: 20)
#   DOS_BOOT_FLOPPY       If set, also runs harness/mame/run-driver-tests.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "== Python (tests/) =="
python3 -m unittest discover -s tests -p 'test_*.py' -v

echo "== Rust (host/xtmax-host) =="
cargo test --manifest-path host/xtmax-host/Cargo.toml

PATCHED_MAME="${ROOT}/harness/mame/artifacts/mame-src-mame0264/mame"
export MAME_SECONDS_TO_RUN="${MAME_SECONDS_TO_RUN:-90}"

if [[ -x "${PATCHED_MAME}" ]]; then
  echo "== MAME XTMax device regressions (patched MAME) =="
  ./harness/mame/run-xtmax-device-tests.sh
  ./harness/mame/run-xtmax-bootrom-tests.sh
  ./harness/mame/run-xtmax-menu-tests.sh
  ./harness/mame/run-xtmax-storage-tests.sh
  ./harness/mame/run-xtmax-ems-tests.sh
  ./harness/mame/run-xtmax-mirror-tests.sh
else
  echo "== Skipping MAME XTMax regressions (no executable at ${PATCHED_MAME}) ==" >&2
  echo "   Build with: ./harness/mame/build-mame-xtmax.sh" >&2
fi

echo "== MAME stock smoke (short) =="
MAME_SECONDS_TO_RUN="${MAME_SMOKE_SECONDS:-20}" ./harness/mame/run-smoke.sh

if [[ -n "${DOS_BOOT_FLOPPY:-}" ]]; then
  echo "== MAME DOS driver tests (DOS_BOOT_FLOPPY set) =="
  ./harness/mame/run-driver-tests.sh
else
  echo "== Skipping run-driver-tests.sh (set DOS_BOOT_FLOPPY to a bootable DOS .img) =="
fi

echo "All runnable tests finished OK."
