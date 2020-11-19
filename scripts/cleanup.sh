#!/bin/bash -eux
# Based on https://github.com/chef/bento/blob/master/packer_templates/ubuntu/scripts/cleanup.sh

export HISTSIZE=0
export HISTFILESIZE=0

dpkg --list | awk '{ print $2 }' | grep 'linux-headers' | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-image-.*-generic' | grep -v "$(uname -r)" | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-modules-.*-generic' | grep -v "$(uname -r)" | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep linux-source | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -- '-doc$' | xargs apt-get --assume-yes purge;

rm -rf /lib/firmware/*
rm -rf /usr/share/doc/linux-firmware/*

apt-get --assume-yes autoremove;
apt-get --assume-yes clean;

find /var/cache -type f -exec rm -rf {} \;

find /var/log -type f -exec truncate --size=0 {} \;

truncate -s 0 /etc/machine-id

rm -rf /tmp/* /var/tmp/*

rm -f /var/lib/systemd/random-seed

rm -f /root/.wget-hsts
