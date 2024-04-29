#!/bin/bash

set -eux

export ANSIBLE_PRIVATE_ROLE_VARS=true
export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0
export PATH=$PATH:$HOME/.local/bin

apt-get update
apt-get --assume-yes --no-install-recommends install pipx

pipx install ansible-core
pipx ensurepath

curl -fsSL https://raw.githubusercontent.com/konstruktoid/ansible-role-hardening/master/requirements.yml | tee /tmp/requirements.yml

ansible-galaxy install -r /tmp/requirements.yml

cd /tmp || exit 1

ansible-playbook -i '127.0.0.1,' -c local ./local.yml

if id vagrant; then
  chage --maxdays 365 vagrant
  chage --mindays 1 vagrant
fi

rm -rvf /tmp/*.yml /tmp/*.cfg

pipx uninstall-all

unset PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

reboot
