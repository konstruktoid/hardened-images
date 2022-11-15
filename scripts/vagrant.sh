#!/bin/bash -eux

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

HOME_DIR="/home/vagrant"
VAGRANT_KEY="https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub"

apt-get --assume-yes update

rm -vf /etc/ssh/*_key /etc/ssh/*_key.pub

dpkg-reconfigure openssh-server

mkdir -p "${HOME_DIR}/.ssh";
chmod 0700 "${HOME_DIR}/.ssh";
curl -sSL "${VAGRANT_KEY}" > "${HOME_DIR}/.ssh/authorized_keys";
chmod 0600 "${HOME_DIR}/.ssh/authorized_keys";
chown -R vagrant:vagrant "${HOME_DIR}";
