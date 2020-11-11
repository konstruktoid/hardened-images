#!/bin/bash -eux

export HISTSIZE=0
export HISTFILESIZE=0

HOME_DIR="/home/vagrant"
VAGRANT_KEY="https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub"

apt-get -y update;
apt-get -y dist-upgrade -o Dpkg::Options::="--force-confnew";

mkdir -p "${HOME_DIR}/.ssh";
chmod 0700 "${HOME_DIR}/.ssh";
curl -sSL "${VAGRANT_KEY}" > "${HOME_DIR}/.ssh/authorized_keys";
chmod 0600 "${HOME_DIR}/.ssh/authorized_keys";
chown -R vagrant:vagrant "${HOME_DIR}";

if id vagrant; then
  chage --maxdays 365 vagrant
  chage --mindays 1 vagrant
fi

reboot
