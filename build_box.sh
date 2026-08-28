#!/bin/bash
set -euo pipefail

TEMPLATE="ubuntu-hardened-qemu.pkr.hcl"

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${BASE_DIR}/output"

cd -- "${BASE_DIR}"

for cmd in packer shellcheck ssh-keygen sha256sum; do
  command -v "${cmd}" > /dev/null 2>&1 || {
    printf 'error: %s is required but was not found in PATH\n' "${cmd}" >&2
    exit 1
  }
done

shellcheck -x -s bash -f gcc \
  build_box.sh run_qemu.sh azure_vars_export scripts/*.sh tools/*.sh

KEY_DIR="$(mktemp --directory -t packer-ssh.XXXXXX)"
chmod 0700 "${KEY_DIR}"
trap 'rm -rf -- "${KEY_DIR}"' EXIT

ssh-keygen -t ed25519 -N "" -C "packer-build" -f "${KEY_DIR}/id_ed25519" -q

mkdir -p -- "${OUTPUT_DIR}"

declare -A PREEXISTING_BUILDS=()
while IFS= read -r -d '' dir; do
  PREEXISTING_BUILDS["${dir}"]=1
done < <(find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 -type d -print0)

packer init -upgrade "./${TEMPLATE}"

packer validate \
  -var "ssh_public_key_file=${KEY_DIR}/id_ed25519.pub" \
  -var "ssh_private_key_file=${KEY_DIR}/id_ed25519" \
  "$@" \
  "./${TEMPLATE}"

packer build \
  -var "ssh_public_key_file=${KEY_DIR}/id_ed25519.pub" \
  -var "ssh_private_key_file=${KEY_DIR}/id_ed25519" \
  "$@" \
  "./${TEMPLATE}"

while IFS= read -r -d '' build_dir; do
  if [ -n "${PREEXISTING_BUILDS["${build_dir}"]:-}" ]; then
    continue
  fi

  printf 'Writing checksums for %s\n' "${build_dir}"
  (
    cd -- "${build_dir}"
    printf '# %s SHA256 checksums\n' "$(date --utc +%FT%TZ)" > CHECKSUMS
    find . -maxdepth 1 -type f \
      \( -name '*.qcow2' -o -name '*.json' \) -printf '%P\0' \
      | sort -z \
      | xargs -0 -r sha256sum >> CHECKSUMS
  )
done < <(find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
