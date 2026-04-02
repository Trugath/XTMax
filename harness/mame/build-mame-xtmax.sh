#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

upstream_tag="$(xtmax_mame_upstream_tag)"
source_dir="$(xtmax_mame_source_dir)"
patch_file="${XTMAX_MAME_PATCHES_DIR}/0001-add-xtmax-phase1-card.patch"
stamp_file="${source_dir}/.xtmax-phase1-applied"
jobs="${XTMAX_MAME_JOBS:-$(nproc)}"
skip_build=""
force_reapply=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fetch-only|--skip-build)
      skip_build=1
      shift
      ;;
    --force-reapply)
      force_reapply=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--skip-build] [--force-reapply]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${patch_file}" ]]; then
  echo "Patch file not found: ${patch_file}" >&2
  exit 1
fi

mkdir -p "${XTMAX_MAME_ARTIFACTS_DIR}"

if [[ ! -d "${source_dir}/src" ]]; then
  archive_dir="$(mktemp -d)"
  trap 'rm -rf "${archive_dir}"' EXIT
  archive_path="${archive_dir}/${upstream_tag}.tar.gz"

  echo "Fetching MAME ${upstream_tag} source into ${source_dir}"
  curl -L --fail "https://codeload.github.com/mamedev/mame/tar.gz/refs/tags/${upstream_tag}" -o "${archive_path}"
  rm -rf "${source_dir}"
  mkdir -p "${source_dir}"
  tar -xzf "${archive_path}" -C "${source_dir}" --strip-components=1
fi

if [[ -n "${force_reapply}" ]]; then
  rm -f "${stamp_file}"
fi

if [[ ! -f "${stamp_file}" ]]; then
  echo "Applying XTMax phase-1 patch"
  patch --forward --strip=1 --directory="${source_dir}" < "${patch_file}"
  printf '%s\n' "${upstream_tag}" > "${stamp_file}"
fi

stage_xtmax_device_bootrom

if [[ -n "${skip_build}" ]]; then
  echo "Fetched and patched ${source_dir}"
  exit 0
fi

echo "Building patched MAME in ${source_dir}"
make -C "${source_dir}" -j"${jobs}"

patched_bin="$(xtmax_mame_patched_bin)"
if [[ ! -x "${patched_bin}" ]]; then
  echo "Build completed but patched MAME binary was not found at ${patched_bin}" >&2
  exit 1
fi

echo "Patched MAME binary: ${patched_bin}"
