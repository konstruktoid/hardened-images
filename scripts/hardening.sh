#!/bin/bash -eux

export ANSIBLE_PRIVATE_ROLE_VARS=true
export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

apt-get --assume-yes update
apt-get --assume-yes --no-install-recommends install software-properties-common

add-apt-repository --yes ppa:ansible/ansible
apt-get --assume-yes update
apt-get --assume-yes --no-install-recommends install ansible

cd /tmp || exit 1

ansible-playbook -i '127.0.0.1,' -c local ./local.yml

systemctl restart sshd

if id vagrant; then
  chage --maxdays 365 vagrant
  chage --mindays 1 vagrant
fi
