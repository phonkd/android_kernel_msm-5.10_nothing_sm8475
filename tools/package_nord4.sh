#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Package Nord 4 kernel build artifacts into a redistributable archive.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out}"
DIST_ROOT="${DIST_ROOT:-${ROOT_DIR}/dist}"
STAMP="$(date +%Y%m%d-%H%M%S)"
PKG_DIR="${DIST_ROOT}/nord4-${STAMP}"

for path in "${OUT_DIR}/arch/arm64/boot/Image" \
            "${OUT_DIR}/arch/arm64/boot/Image.gz" \
            "${OUT_DIR}/System.map" \
            "${OUT_DIR}/Module.symvers"; do
	if [[ ! -f "${path}" ]]; then
		echo "Missing expected build artifact: ${path}" >&2
		exit 1
	fi
done

rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"/{images,dtbs,modules}

cp "${OUT_DIR}/arch/arm64/boot/Image" "${PKG_DIR}/images/"
cp "${OUT_DIR}/arch/arm64/boot/Image.gz" "${PKG_DIR}/images/"
cp "${OUT_DIR}/System.map" "${PKG_DIR}/"
cp "${OUT_DIR}/Module.symvers" "${PKG_DIR}/"

find "${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom" -maxdepth 1 -type f -name "neo*.dtb" -exec cp {} "${PKG_DIR}/dtbs/" \;
find "${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom" -maxdepth 1 -type f -name "neo*.dtbo" -exec cp {} "${PKG_DIR}/dtbs/" \;

rsync -a --prune-empty-dirs \
	--include='*/' \
	--include='*.ko' \
	--exclude='*' \
	"${OUT_DIR}/" "${PKG_DIR}/modules/"

ARCHIVE="nord4-kernel-${STAMP}.tar.gz"
tar -C "${DIST_ROOT}" -czf "${DIST_ROOT}/${ARCHIVE}" "nord4-${STAMP}"

echo "Packaged kernel artifacts:"
echo "  ${PKG_DIR}"
echo "  ${DIST_ROOT}/${ARCHIVE}"
