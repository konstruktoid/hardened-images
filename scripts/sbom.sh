#!/bin/bash
set -euo pipefail

SYFT_VERSION="${SYFT_VERSION:-v1.46.0}"
SYFT_BIN_DIR="${SYFT_BIN_DIR:-/usr/local/bin}"

readonly SYFT_RELEASE="https://github.com/anchore/syft/releases/download/${SYFT_VERSION}"
readonly SYFT_ARCHIVE="syft_${SYFT_VERSION#v}_linux_amd64.tar.gz"
readonly SYFT_CHECKSUMS="syft_${SYFT_VERSION#v}_checksums.txt"

WORK_DIR="$(mktemp --directory -t syft.XXXXXX)"
trap 'rm -rf -- "${WORK_DIR}"; rm -f -- "${SYFT_BIN_DIR}/syft"' EXIT

curl -fsSL --retry 3 --max-time 300 \
  -o "${WORK_DIR}/${SYFT_ARCHIVE}" "${SYFT_RELEASE}/${SYFT_ARCHIVE}"
curl -fsSL --retry 3 --max-time 60 \
  -o "${WORK_DIR}/${SYFT_CHECKSUMS}" "${SYFT_RELEASE}/${SYFT_CHECKSUMS}"

(
  cd "${WORK_DIR}"
  grep " ${SYFT_ARCHIVE}\$" "${SYFT_CHECKSUMS}" > expected.sha256
  [ -s expected.sha256 ]
  sha256sum --check --strict expected.sha256
)

tar --extract --gzip --file "${WORK_DIR}/${SYFT_ARCHIVE}" \
  --directory "${WORK_DIR}" syft
install -m 0755 "${WORK_DIR}/syft" "${SYFT_BIN_DIR}/syft"

"${SYFT_BIN_DIR}/syft" scan dir:/ \
  --exclude "**${SYFT_BIN_DIR}/syft" \
  --exclude "**${WORK_DIR}/**" \
  -o "spdx-json=/tmp/sbom.spdx.json" \
  -o "cyclonedx-json=/tmp/sbom.cdx.json"

chmod 0644 /tmp/sbom.spdx.json /tmp/sbom.cdx.json
