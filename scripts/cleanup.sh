#!/bin/bash -eux

export HISTSIZE=0
export HISTFILESIZE=0

apt-get -y autoremove;
apt-get -y clean;

find /var/cache -type f -exec rm -rf {} \;

find /var/log -type f -exec truncate --size=0 {} \;

truncate -s 0 /etc/machine-id

rm -rf /tmp/* /var/tmp/*

rm -f /var/lib/systemd/random-seed

rm -f /root/.wget-hsts
