#!/bin/bash
set -eux -o pipefail

shellcheck -x -s bash -f gcc scripts/*

BASE_DIR="$(pwd)"
GIT_CLONE_DIR="$(mktemp --directory -p /var/tmp bento.XXXXXX)"

mkdir -p "${BASE_DIR}/output"

git clone https://github.com/chef/bento.git "${GIT_CLONE_DIR}"

cp -r "${BASE_DIR}/scripts/hardening.sh" "${GIT_CLONE_DIR}/packer_templates/scripts/"
cp -r "${BASE_DIR}/scripts/sbom.sh" "${GIT_CLONE_DIR}/packer_templates/scripts/"
cp -r "${BASE_DIR}/config/" "${GIT_CLONE_DIR}/packer_templates/config"

cd "${GIT_CLONE_DIR}" || exit 1

git apply ./packer_templates/config/bento.diff

mkdir -p ./sbom

packer init -upgrade ./packer_templates
find . -name 'ubuntu-26.*-x86_64.pkrvars.hcl' | while read -r template; do
  packer build -only="qemu.vm" -var-file="${template}" \
    -var 'qemu_efi_firmware_code=/usr/share/OVMF/OVMF_CODE_4M.fd' \
    -var 'qemu_efi_firmware_vars=/usr/share/OVMF/OVMF_VARS_4M.fd' \
  ./packer_templates

  find ./builds/build_complete -maxdepth 1 -type f -name '*.box' | while read -r box; do
    tar -xf "${box}" -C "${BASE_DIR}/output" box_0.img
    mv -v "${BASE_DIR}/output/box_0.img" "${BASE_DIR}/output/$(basename "${box}" .box).qcow2"

    for ext in spdx cdx; do
      if [ -f "./sbom/sbom.${ext}.json" ]; then
        mv -v "./sbom/sbom.${ext}.json" "${BASE_DIR}/output/$(basename "${box}" .box).${ext}.json"
      fi
    done
  done
done

cd "${BASE_DIR}" || exit 1
rm -rf "${GIT_CLONE_DIR}"
