#!/usr/bin/env bash
set -euo pipefail

readonly XTMAX_HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly XTMAX_REPO_ROOT="$(cd "${XTMAX_HARNESS_ROOT}/../.." && pwd)"
readonly XTMAX_MAME_ARTIFACTS_DIR="${XTMAX_HARNESS_ROOT}/artifacts"
readonly XTMAX_MAME_CONFIG_TEMPLATE="${XTMAX_HARNESS_ROOT}/config/mame.ini.template"
readonly XTMAX_MAME_CONFIG_FILE="${XTMAX_MAME_ARTIFACTS_DIR}/mame.ini"
readonly XTMAX_MAME_REPO_ROMS_DIR="${XTMAX_HARNESS_ROOT}/roms"
readonly XTMAX_MAME_ROMS_DIR="${XTMAX_MAME_ARTIFACTS_DIR}/roms"
readonly XTMAX_MAME_PATCHES_DIR="${XTMAX_HARNESS_ROOT}/patches"

default_extra_rompath() {
  local parent_dir="${XTMAX_REPO_ROOT}/.."

  if compgen -G "${parent_dir}/*BIOS*.BIN" >/dev/null; then
    printf '%s\n' "${parent_dir}"
    return 0
  fi

  return 1
}

combined_rompath() {
  local rompath="${XTMAX_MAME_REPO_ROMS_DIR};${XTMAX_MAME_ROMS_DIR}"
  local extra_rompath="${XTMAX_MAME_EXTRA_ROMPATH:-}"

  if [[ -z "${extra_rompath}" ]]; then
    extra_rompath="$(default_extra_rompath || true)"
  fi

  if [[ -n "${extra_rompath}" ]]; then
    rompath="${rompath};${extra_rompath}"
  fi

  printf '%s\n' "${rompath}"
}

xtmax_mame_upstream_tag() {
  printf '%s\n' "${XTMAX_MAME_UPSTREAM_TAG:-mame0264}"
}

xtmax_mame_source_dir() {
  local tag
  tag="$(xtmax_mame_upstream_tag)"
  printf '%s\n' "${XTMAX_MAME_ARTIFACTS_DIR}/mame-src-${tag}"
}

xtmax_mame_patched_bin() {
  printf '%s\n' "${XTMAX_MAME_PATCHED_BIN:-$(xtmax_mame_source_dir)/mame}"
}

build_xtmax_boot_image_from_asm() {
  local asm_src="$1"
  local boot_bin="$2"
  local image_path="$3"

  if [[ ! -f "${asm_src}" ]]; then
    echo "XTMax boot sector source not found: ${asm_src}" >&2
    return 1
  fi

  if ! command -v nasm >/dev/null 2>&1; then
    echo "nasm is required to build XTMax boot images." >&2
    return 1
  fi

  mkdir -p "$(dirname "${image_path}")"
  mkdir -p "$(dirname "${boot_bin}")"
  nasm -f bin -o "${boot_bin}" "${asm_src}"
  cp "${boot_bin}" "${image_path}"
}

build_xtmax_test_boot_image() {
  build_xtmax_boot_image_from_asm \
    "${XTMAX_HARNESS_ROOT}/boot/xtmax_test_boot.asm" \
    "${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-test-boot.bin" \
    "$1"
}

build_xtmax_invalid_boot_image() {
  build_xtmax_boot_image_from_asm \
    "${XTMAX_HARNESS_ROOT}/boot/xtmax_invalid_boot.asm" \
    "${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-invalid-boot.bin" \
    "$1"
}

build_xtmax_rw_boot_image() {
  build_xtmax_boot_image_from_asm \
    "${XTMAX_HARNESS_ROOT}/boot/xtmax_rw_boot.asm" \
    "${XTMAX_MAME_ARTIFACTS_DIR}/xtmax-rw-boot.bin" \
    "$1"
}

stage_xtmax_device_bootrom() {
  local bootrom_src="${XTMAX_REPO_ROOT}/firmware/teensy/bootrom.bin"
  local bootrom_dir="${XTMAX_MAME_ROMS_DIR}/xtmax"
  local bootrom_dst="${bootrom_dir}/xtmax_bootrom.bin"

  if [[ ! -f "${bootrom_src}" ]]; then
    echo "XTMax Boot ROM image not found: ${bootrom_src}" >&2
    return 1
  fi

  mkdir -p "${bootrom_dir}"
  ln -sfn "${bootrom_src}" "${bootrom_dst}"
}

stage_known_rom_aliases() {
  local source_u18="${XTMAX_MAME_REPO_ROMS_DIR}/BIOS_5160_08NOV82_U18_1501512.BIN"
  local source_u19="${XTMAX_MAME_REPO_ROMS_DIR}/BIOS_5160_08NOV82_U19_5000027.BIN"
  local source_font="${XTMAX_MAME_REPO_ROMS_DIR}/5788005.u33"
  local source_kb3270="${XTMAX_MAME_REPO_ROMS_DIR}/14166.bin"
  local source_wdbios="${XTMAX_MAME_REPO_ROMS_DIR}/wdbios.rom"

  if [[ -f "${source_u18}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/1501512.u18" ]]; then
    ln -s "$(basename "${source_u18}")" "${XTMAX_MAME_REPO_ROMS_DIR}/1501512.u18"
  fi

  if [[ -f "${source_u19}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/5000027.u19" ]]; then
    ln -s "$(basename "${source_u19}")" "${XTMAX_MAME_REPO_ROMS_DIR}/5000027.u19"
  fi

  mkdir -p \
    "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155" \
    "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5160" \
    "${XTMAX_MAME_REPO_ROMS_DIR}/cga" \
    "${XTMAX_MAME_REPO_ROMS_DIR}/isa_hdc" \
    "${XTMAX_MAME_REPO_ROMS_DIR}/keytronic_pc3270" \
    "${XTMAX_MAME_REPO_ROMS_DIR}/kb_pcxt83"

  if [[ -f "${source_u18}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155/1501512.u18" ]]; then
    ln -s "../$(basename "${source_u18}")" "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155/1501512.u18"
  fi

  if [[ -f "${source_u19}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155/5000027.u19" ]]; then
    ln -s "../$(basename "${source_u19}")" "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155/5000027.u19"
  fi

  if [[ -f "${source_font}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155/5788005.u33" ]]; then
    ln -s "../$(basename "${source_font}")" "${XTMAX_MAME_REPO_ROMS_DIR}/ibm5155/5788005.u33"
  fi

  if [[ -f "${source_font}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/cga/5788005.u33" ]]; then
    ln -s "../$(basename "${source_font}")" "${XTMAX_MAME_REPO_ROMS_DIR}/cga/5788005.u33"
  fi

  if [[ -f "${source_kb3270}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/keytronic_pc3270/14166.bin" ]]; then
    ln -s "../$(basename "${source_kb3270}")" "${XTMAX_MAME_REPO_ROMS_DIR}/keytronic_pc3270/14166.bin"
  fi

  if [[ -f "${source_wdbios}" && ! -e "${XTMAX_MAME_REPO_ROMS_DIR}/isa_hdc/wdbios.rom" ]]; then
    ln -s "../$(basename "${source_wdbios}")" "${XTMAX_MAME_REPO_ROMS_DIR}/isa_hdc/wdbios.rom"
  fi
}

ensure_mame_dirs_for() {
  local base_dir="$1"
  mkdir -p \
    "${base_dir}" \
    "${XTMAX_MAME_ROMS_DIR}" \
    "${base_dir}/cfg" \
    "${base_dir}/nvram" \
    "${base_dir}/input" \
    "${base_dir}/state" \
    "${base_dir}/snap"
}

ensure_mame_dirs() {
  ensure_mame_dirs_for "${XTMAX_MAME_ARTIFACTS_DIR}"
}

escape_sed_path() {
  printf '%s' "$1" | sed 's/[|&]/\\&/g'
}

render_mame_config_to() {
  local base_dir="$1"
  local config_file="${base_dir}/mame.ini"
  ensure_mame_dirs_for "${base_dir}"
  stage_known_rom_aliases
  local rompath
  rompath="$(combined_rompath)"

  sed \
    -e "s|@HOMEPATH@|$(escape_sed_path "${base_dir}")|g" \
    -e "s|@ROMPATH@|$(escape_sed_path "${rompath}")|g" \
    -e "s|@CFGDIR@|$(escape_sed_path "${base_dir}/cfg")|g" \
    -e "s|@NVRAMDIR@|$(escape_sed_path "${base_dir}/nvram")|g" \
    -e "s|@INPUTDIR@|$(escape_sed_path "${base_dir}/input")|g" \
    -e "s|@STATEDIR@|$(escape_sed_path "${base_dir}/state")|g" \
    -e "s|@SNAPDIR@|$(escape_sed_path "${base_dir}/snap")|g" \
    -e "s|@DIFFDIR@|$(escape_sed_path "${base_dir}/diff")|g" \
    "${XTMAX_MAME_CONFIG_TEMPLATE}" > "${config_file}"
}

render_mame_config() {
  render_mame_config_to "${XTMAX_MAME_ARTIFACTS_DIR}"
}

find_mame_bin() {
  if [[ -n "${MAME_BIN:-}" ]]; then
    printf '%s\n' "${MAME_BIN}"
    return 0
  fi

  if command -v mame >/dev/null 2>&1; then
    command -v mame
    return 0
  fi

  return 1
}

install_mame() {
  if find_mame_bin >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y mame
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y mame
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed mame
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    brew install mame
    return 0
  fi

  echo "Unable to install MAME automatically on this host." >&2
  echo "Install MAME manually and re-run with MAME_BIN=/path/to/mame if needed." >&2
  return 1
}

require_machine_rom() {
  local machine="$1"
  local extra_rompath="${XTMAX_MAME_EXTRA_ROMPATH:-}"

  if [[ -z "${extra_rompath}" ]]; then
    extra_rompath="$(default_extra_rompath || true)"
  fi

  if [[ -f "${XTMAX_MAME_ROMS_DIR}/${machine}.zip" ]]; then
    return 0
  fi

  if [[ -f "${XTMAX_MAME_REPO_ROMS_DIR}/${machine}.zip" ]]; then
    return 0
  fi

  if [[ -d "${XTMAX_MAME_REPO_ROMS_DIR}/${machine}" ]] && find "${XTMAX_MAME_REPO_ROMS_DIR}/${machine}" -maxdepth 1 -type f -o -type l | grep -q .; then
    return 0
  fi

  if [[ -d "${XTMAX_MAME_ROMS_DIR}/${machine}" ]] && find "${XTMAX_MAME_ROMS_DIR}/${machine}" -maxdepth 1 -type f -o -type l | grep -q .; then
    return 0
  fi

  if [[ -n "${extra_rompath}" ]]; then
    echo "No ${machine}.zip in ${XTMAX_MAME_REPO_ROMS_DIR} or ${XTMAX_MAME_ROMS_DIR}; relying on external ROM path: ${extra_rompath}" >&2
    return 0
  fi

  echo "Missing ROM set: ${XTMAX_MAME_REPO_ROMS_DIR}/${machine}.zip" >&2
  echo "Place a compatible MAME ROM zip in ${XTMAX_MAME_REPO_ROMS_DIR} or ${XTMAX_MAME_ROMS_DIR}, or set XTMAX_MAME_EXTRA_ROMPATH." >&2
  return 1
}

required_files_for_machine() {
  local machine="$1"

  case "${machine}" in
    ibm5155)
      cat <<'EOF'
ibm5155/1501512.u18
ibm5155/5000027.u19
ibm5155/5788005.u33
cga/5788005.u33
keytronic_pc3270/14166.bin
isa_hdc/wdbios.rom
EOF
      ;;
    ibm5160)
      cat <<'EOF'
ibm5160/68x4370.u19
ibm5160/62x0890.u18
cga/5788005.u33
kb_pcxt83/4584751.m1
isa_hdc/wdbios.rom
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

find_rom_file() {
  local filename="$1"
  local extra_rompath="${XTMAX_MAME_EXTRA_ROMPATH:-}"

  if [[ -f "${XTMAX_MAME_REPO_ROMS_DIR}/${filename}" ]]; then
    printf '%s\n' "${XTMAX_MAME_REPO_ROMS_DIR}/${filename}"
    return 0
  fi

  if [[ -f "${XTMAX_MAME_ROMS_DIR}/${filename}" ]]; then
    printf '%s\n' "${XTMAX_MAME_ROMS_DIR}/${filename}"
    return 0
  fi

  if [[ -z "${extra_rompath}" ]]; then
    extra_rompath="$(default_extra_rompath || true)"
  fi

  if [[ -n "${extra_rompath}" && -f "${extra_rompath}/${filename}" ]]; then
    printf '%s\n' "${extra_rompath}/${filename}"
    return 0
  fi

  return 1
}
