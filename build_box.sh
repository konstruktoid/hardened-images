#!/bin/bash -eux

packer validate ubuntu-hardened-20.04-packer.json || exit 1
vagrant validate Vagrantfile || exit 1
vagrant destroy
vagrant box remove ubuntu-hardened/20.04 --all
rm -rvf ./output
packer build -force -timestamp-ui ubuntu-hardened-20.04-packer.json
