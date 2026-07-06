#!/bin/bash

set -eux

export ANSIBLE_PRIVATE_ROLE_VARS=true
export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0
export PATH="${PATH}:${HOME}/.local/bin"

apt-get --assume-yes --no-install-recommends --update install git pipx

pipx install ansible-core
pipx ensurepath

curl -fsSL https://raw.githubusercontent.com/konstruktoid/ansible-role-hardening/master/requirements.yml | tee /tmp/requirements.yml

ansible-galaxy install -r /tmp/requirements.yml

cd /tmp || exit 1

ansible-playbook -i '127.0.0.1,' -c local ./local.yml

if id ubuntu > /dev/null 2>&1; then
  chage --maxdays 365 ubuntu
  chage --mindays 1 ubuntu
fi

rm -rvf /tmp/*.yml /tmp/*.cfg /etc/ansible
rm -rf "${HOME}/.ansible"

pipx uninstall-all
rm -rf "${HOME}/.local"

unset PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

apt-get --assume-yes purge git pipx open-vm-tools "linux-headers-$(uname -r)" linux-headers-generic
apt-get --assume-yes autoremove
apt-get --assume-yes clean
