#!/usr/bin/env bash
set -euo pipefail

# Simple helper to build the Nothing Phone (2) kernel tree.

usage() {
  cat <<'EOF'
Usage: build_kernel.sh [options]

Options:
  -p, --package   Run tools/package_nord4.sh after a successful build
  -h, --help      Show this help message

Environment overrides:
  OUT_DIR                Output directory (default: <repo>/out)
  DEFCONFIG              Kernel defconfig target (default: generic_sxr_defconfig)
  VENDOR_CONFIG          Space separated config fragments (default: arch/arm64/configs/vendor/neo_le.config)
  EXTRA_CONFIGS          Additional fragments appended to VENDOR_CONFIG (default: arch/arm64/configs/vendor/docker_support.config)
  JOBS                   Parallel build jobs (default: nproc)
  ARCH, LLVM, LLVM_IAS, CROSS_COMPILE, CROSS_COMPILE_COMPAT  Toolchain knobs
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out}"
DEFCONFIG="${DEFCONFIG:-generic_sxr_defconfig}"
VENDOR_CONFIG="${VENDOR_CONFIG:-arch/arm64/configs/vendor/neo_le.config}"
EXTRA_CONFIGS="${EXTRA_CONFIGS:-arch/arm64/configs/vendor/docker_support.config}"
JOBS="${JOBS:-$(nproc)}"
RUN_PACKAGE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--package)
      RUN_PACKAGE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "${OUT_DIR}"

export ARCH="${ARCH:-arm64}"
export LLVM="${LLVM:-1}"
export LLVM_IAS="${LLVM_IAS:-1}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export CROSS_COMPILE_COMPAT="${CROSS_COMPILE_COMPAT:-arm-linux-gnueabihf-}"

run() {
  echo "==> $*"
  "$@"
}

cd "${ROOT_DIR}"

run make O="${OUT_DIR}" "${DEFCONFIG}"
CONFIG_FRAGMENTS=()
for cfg in ${VENDOR_CONFIG} ${EXTRA_CONFIGS}; do
  [[ -z "${cfg}" ]] && continue
  case "${cfg}" in
    /*)
      path="${cfg}"
      ;;
    *)
      path="${ROOT_DIR}/${cfg}"
      ;;
  esac
  if [[ ! -f "${path}" ]]; then
    echo "Config fragment not found: ${path}" >&2
    exit 1
  fi
  CONFIG_FRAGMENTS+=("${path}")
done

run env KCONFIG_CONFIG="${OUT_DIR}/.config" ./scripts/kconfig/merge_config.sh -m "${OUT_DIR}/.config" "${CONFIG_FRAGMENTS[@]}"
run make O="${OUT_DIR}" olddefconfig
run make -j"${JOBS}" O="${OUT_DIR}" Image modules dtbs

if [[ "${RUN_PACKAGE}" -eq 1 ]]; then
  run ./tools/package_nord4.sh
fi

cat <<EOF

Build complete.
Kernel image: ${OUT_DIR}/arch/arm64/boot/Image
DTBs:         ${OUT_DIR}/arch/arm64/boot/dts/vendor/
Modules:      find ${OUT_DIR} -name '*.ko'
EOF
