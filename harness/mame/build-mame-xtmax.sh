#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

upstream_tag="$(xtmax_mame_upstream_tag)"
source_dir="$(xtmax_mame_source_dir)"
patch_file="${XTMAX_MAME_PATCHES_DIR}/0001-add-xtmax-phase1-card.patch"
stamp_file="${source_dir}/.xtmax-phase1-applied"
jobs="${XTMAX_MAME_JOBS:-$(nproc)}"
make_args_string="${XTMAX_MAME_MAKE_ARGS:-REGENIE=1 USE_QTDEBUG=0}"
deps_dir="${XTMAX_MAME_ARTIFACTS_DIR}/deps"
fontconfig_dep_root="${deps_dir}/fontconfig"
declare -a make_args
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

if [[ -n "${make_args_string}" ]]; then
  # Intentional shell splitting so callers can pass multiple make variables.
  # shellcheck disable=SC2206
  make_args=( ${make_args_string} )
fi

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

if ! pkg-config --exists fontconfig; then
  multiarch="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
  pc_file="${fontconfig_dep_root}/usr/lib/${multiarch}/pkgconfig/fontconfig.pc"

  if [[ ! -f "${pc_file}" ]]; then
    download_dir="$(mktemp -d)"
    trap 'rm -rf "${archive_dir:-}" "${download_dir:-}"' EXIT
    echo "Bootstrapping local libfontconfig-dev into ${fontconfig_dep_root}"
    (
      cd "${download_dir}"
      apt download libfontconfig-dev >/dev/null
    )
    deb_path="$(find "${download_dir}" -maxdepth 1 -name 'libfontconfig-dev_*.deb' | head -n 1)"
    if [[ -z "${deb_path}" ]]; then
      echo "Failed to download libfontconfig-dev" >&2
      exit 1
    fi
    rm -rf "${fontconfig_dep_root}"
    mkdir -p "${fontconfig_dep_root}"
    dpkg-deb -x "${deb_path}" "${fontconfig_dep_root}"
  fi

  export PKG_CONFIG_PATH="${fontconfig_dep_root}/usr/lib/${multiarch}/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
fi

stage_xtmax_device_bootrom

if [[ -n "${skip_build}" ]]; then
  echo "Fetched and patched ${source_dir}"
  exit 0
fi

echo "Building patched MAME in ${source_dir}"
make -C "${source_dir}" -j"${jobs}" "${make_args[@]}"

patched_bin="$(xtmax_mame_patched_bin)"
if [[ ! -x "${patched_bin}" ]]; then
  echo "Build completed but patched MAME binary was not found at ${patched_bin}" >&2
  exit 1
fi

echo "Patched MAME binary: ${patched_bin}"
