#!/bin/bash
set -eux -o pipefail

SYFT_VERSION="v1.46.0"
SYFT_BIN_DIR="/usr/local/bin"

curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh | \
  sh -s -- -b "${SYFT_BIN_DIR}" "${SYFT_VERSION}"

"${SYFT_BIN_DIR}/syft" scan dir:/ \
  --exclude "**${SYFT_BIN_DIR}/syft" \
  -o spdx-json=/tmp/sbom.spdx.json \
  -o cyclonedx-json=/tmp/sbom.cdx.json

chmod 0644 /tmp/sbom.spdx.json /tmp/sbom.cdx.json

rm -f "${SYFT_BIN_DIR}/syft"
