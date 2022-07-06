#!/bin/bash
set -e -o pipefail

vagrant validate Vagrantfile || exit 1
shellcheck -x -s bash -f gcc scripts/* || exit 1

vagrant destroy --force

grep -o 'box = ".*"' Vagrantfile | awk -F '"' '{print $2}' | while read -r BOX; do
  vagrant box remove "${BOX}" --all || true
done

rm -rvf ./output

packer_validate()(
  echo "Validating $2 using $1."
  packer validate -var-file "$1" "$2" || exit 1
)

packer_build()(
  echo "Building $2 using $1."
  packer build -force -timestamp-ui -var-file "$1" "$2" || exit 1
)

find . -name 'ubuntu-2[0-9].*-vars.json' -type f | while read -r VARS; do
  packer_validate "${VARS}" ubuntu-hardened-box.pkr.hcl
  packer_build "${VARS}" ubuntu-hardened-box.pkr.hcl
done
