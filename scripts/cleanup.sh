#!/bin/bash -eux
# https://github.com/chef/bento/blob/master/packer_templates/ubuntu/scripts/cleanup.sh
# https://github.com/chef/bento/blob/master/packer_templates/_common/minimize.sh

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

systemd-tmpfiles --clean
systemd-tmpfiles --remove

rm -rvf /etc/ansible/*

rm -rvf /etc/apt/sources.list.d/*

dpkg --list | awk '{ print $2 }' | grep 'linux-headers' | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-image-.*-generic' | grep -v "$(uname -r)" | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-modules-.*-generic' | grep -v "$(uname -r)" | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -- '-dev\(:[a-z0-9]\+\)\?$' | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep linux-source | xargs apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -- '-doc$' | xargs apt-get --assume-yes purge;

for PACKAGE in ansible bash-completion command-not-found command-not-found-data \
  fonts-ubuntu-console fonts-ubuntu-font-family-console friendly-recovery \
  grub-legacy-ec2 installation-report laptop-detect libx11-6 libx11-data libxcb1 \
  libxext6 libxmuu1 motd-news-config popularity-contest ppp pppconfig pppoeconf usbutils xauth; do
  apt-get --assume-yes purge "${PACKAGE}" || true
done

cat <<_EOF_ | cat >> /etc/dpkg/dpkg.cfg.d/excludes
#BENTO-BEGIN
path-exclude=/lib/firmware/*
path-exclude=/usr/share/doc/linux-firmware/*
#BENTO-END
_EOF_

rm -rvf /lib/firmware/*
rm -rvf /usr/share/doc/linux-firmware/*

rm -rvf /usr/share/doc/*

apt-get --assume-yes autoremove;
apt-get --assume-yes clean;

find /var/cache -type f -exec rm -rvf {} \;

find /var/log -type f -exec truncate --size=0 {} \;

find /home -type d -name '.ansible' -exec rm -rvf {} \; || true

truncate -s 0 /etc/machine-id

rm -rvf /etc/ansible

rm -rvf /tmp/* /var/tmp/*

rm -vf /var/lib/systemd/random-seed

rm -vf /root/.wget-hsts

export HISTSIZE=0
