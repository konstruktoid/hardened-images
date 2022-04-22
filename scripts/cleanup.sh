#!/bin/bash -eux
# https://github.com/chef/bento/blob/master/packer_templates/ubuntu/scripts/cleanup.sh
# https://github.com/chef/bento/blob/master/packer_templates/_common/minimize.sh

export HISTSIZE=0
export HISTFILESIZE=0

systemd-tmpfiles --clean
systemd-tmpfiles --remove

rm -rf /etc/ansible/roles

rm -rf /etc/apt/sources.list.d/*

dpkg --list | awk '{ print $2 }' | grep 'linux-headers' | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-image-.*-generic' | grep -v "$(uname -r)" | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-modules-.*-generic' | grep -v "$(uname -r)" | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -- '-dev\(:[a-z0-9]\+\)\?$' | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep linux-source | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -- '-doc$' | xargs apt-get --assume-yes purge;

apt-get --assume-yes purge libx11-data xauth libxmuu1 libxcb1 libx11-6 libxext6;

apt-get --assume-yes purge ppp pppconfig pppoeconf;

apt-get --assume-yes purge popularity-contest installation-report command-not-found friendly-recovery bash-completion fonts-ubuntu-font-family-console laptop-detect motd-news-config usbutils grub-legacy-ec2;

apt-get --assume-yes purge fonts-ubuntu-console || true;

apt-get --assume-yes purge command-not-found-data || true;

apt-get --assume-yes purge ansible || true;

cat <<_EOF_ | cat >> /etc/dpkg/dpkg.cfg.d/excludes
#BENTO-BEGIN
path-exclude=/lib/firmware/*
path-exclude=/usr/share/doc/linux-firmware/*
#BENTO-END
_EOF_

rm -rf /lib/firmware/*
rm -rf /usr/share/doc/linux-firmware/*

rm -rf /usr/share/doc/*

apt-get --assume-yes autoremove;
apt-get --assume-yes clean;

find /var/cache -type f -exec rm -rf {} \;

find /var/log -type f -exec truncate --size=0 {} \;

truncate -s 0 /etc/machine-id

rm -rf /etc/ansible

rm -rf /tmp/* /var/tmp/*

rm -f /var/lib/systemd/random-seed

rm -f /root/.wget-hsts

export HISTSIZE=0
