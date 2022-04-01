#!/bin/bash
set -eux -o pipefail

find . -name '*packer.pkr.hcl' -type f -exec packer validate {} \; || exit 1
vagrant validate Vagrantfile || exit 1
shellcheck -x -s bash -f gcc scripts/* || exit 1

vagrant destroy --force hardened
vagrant box remove ubuntu-hardened/20.04 --all || true

rm -rvf ./output

packer build -force -timestamp-ui -var-file ubuntu-20.04-vars.json ubuntu-hardened-packer.pkr.hcl || exit 1
