#!/bin/bash
set -eux

shellcheck -x -s bash -f gcc scripts/*

BASE_DIR="$(pwd)"
GIT_CLONE_DIR="$(mktemp --directory -p /var/tmp bento.XXXXXX)"

mkdir -p "${BASE_DIR}/output"
rm -rvf "${BASE_DIR}/output/*.box"

git clone https://github.com/chef/bento.git "${GIT_CLONE_DIR}"

cp -r "${BASE_DIR}/scripts/hardening.sh" "${GIT_CLONE_DIR}/packer_templates/scripts/"
cp -r "${BASE_DIR}/config/" "${GIT_CLONE_DIR}/packer_templates/config"

cd "${GIT_CLONE_DIR}"

git apply ./packer_templates/config/bento.diff

packer init -upgrade ./packer_templates

find . -name 'ubuntu-2[2-8].04-x86_64.pkrvars.hcl' | while read -r template; do
  packer build -only=virtualbox-iso.vm -var-file="${template}" ./packer_templates
  box_name="$(basename "${template}" | awk -F '-' '{print $2}')"
  find . -name "${box_name}-*.box" | while read -r box; do
    mv "${box}" "${BASE_DIR}/output/"
  done
done

cd "${BASE_DIR}"
echo "${GIT_CLONE_DIR}"
# rm -rf "${GIT_CLONE_DIR}"
