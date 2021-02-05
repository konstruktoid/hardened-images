#!/bin/bash -eux

find . -name '*packer.json' -type f -exec packer validate {} \; || exit 1
vagrant validate Vagrantfile || exit 1
shellcheck -x -s bash -f gcc scripts/* || exit 1

vagrant destroy --force
vagrant box remove ubuntu-hardened/20.04 --all

rm -rvf ./output

packer build -force -timestamp-ui ubuntu-20.04-hardened-packer.json || exit 1
