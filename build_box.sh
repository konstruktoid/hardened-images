#!/bin/bash
set -eux -o pipefail

shellcheck -x -s bash -f gcc scripts/* build_box.sh

BASE_DIR="$(pwd)"
KEY_DIR="$(mktemp --directory -p /var/tmp packer-ssh.XXXXXX)"
trap 'rm -rf "${KEY_DIR}"' EXIT

mkdir -p "${BASE_DIR}/output"

ssh-keygen -t ed25519 -N "" -C "packer-build" -f "${KEY_DIR}/id_ed25519" -q

packer init -upgrade ./ubuntu-hardened-qemu.pkr.hcl
packer build \
  -var "ssh_public_key_file=${KEY_DIR}/id_ed25519.pub" \
  -var "ssh_private_key_file=${KEY_DIR}/id_ed25519" \
  -var 'qemu_efi_firmware_code=/usr/share/OVMF/OVMF_CODE_4M.fd' \
  -var 'qemu_efi_firmware_vars=/usr/share/OVMF/OVMF_VARS_4M.fd' \
  "$@" \
  ./ubuntu-hardened-qemu.pkr.hcl

find "${BASE_DIR}/output" -mindepth 1 -maxdepth 1 -type d | while read -r build_dir; do
  (
    cd "${build_dir}"
    echo "# $(date --utc +%FT%TZ) SHA256 checksums" > "CHECKSUMS"
    for file in *.qcow2 *.json; do
      [ -e "${file}" ] || continue
      sha256sum "${file}" >> "CHECKSUMS"
    done
  )
done
