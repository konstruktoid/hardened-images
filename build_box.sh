#!/bin/bash
set -eux -o pipefail

shellcheck -x -s bash -f gcc scripts/*

BASE_DIR="$(pwd)"
GIT_CLONE_DIR="$(mktemp --directory -p /var/tmp bento.XXXXXX)"
BUILD_ISOS="virtualbox-iso.vm" # "virtualbox-iso.vm,vmware-iso.vm,qemu.vm"

mkdir -p "${BASE_DIR}/output"

git clone https://github.com/chef/bento.git "${GIT_CLONE_DIR}"

cp -r "${BASE_DIR}/scripts/hardening.sh" "${GIT_CLONE_DIR}/packer_templates/scripts/"
cp -r "${BASE_DIR}/config/" "${GIT_CLONE_DIR}/packer_templates/config"

cd "${GIT_CLONE_DIR}"

git apply ./packer_templates/config/bento.diff

packer init -upgrade ./packer_templates
find . -name 'ubuntu-2[4-8].*-x86_64.pkrvars.hcl' | while read -r template; do
  packer build -only="${BUILD_ISOS}" -var-file="${template}" ./packer_templates
  box_name="$(basename "${template}" | awk -F '-' '{print $2}')"
  find . -name "ubuntu-${box_name}-*.box" | while read -r box; do
    mod_name="$(basename "$box" | sed 's/virtualbox/bento-hardened/g')"
    mv -v "${box}" "${BASE_DIR}/output/${mod_name}"
  done
done

cd "${BASE_DIR}"
rm -rf "${GIT_CLONE_DIR}"
