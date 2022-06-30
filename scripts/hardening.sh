#!/bin/bash -eux

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

add-apt-repository --yes ppa:ansible/ansible
apt-get --assume-yes update
apt-get --assume-yes --no-install-recommends install ansible

cd /tmp || exit 1

ansible-playbook -i '127.0.0.1,' -c local ./local.yml

ufw disable;
systemctl restart sshd

find /etc -name '*.bak' -exec rm -f {} \;

if id vagrant; then
  chage --maxdays 365 vagrant
  chage --mindays 1 vagrant
fi
