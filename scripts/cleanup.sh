#!/bin/bash -eux
# https://github.com/chef/bento/blob/main/packer_templates/scripts/ubuntu/cleanup_ubuntu.sh
#
export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

if [ -s /tmp/authorized_keys ]; then
  install -d -m 0700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
  install -m 0600 -o ubuntu -g ubuntu /tmp/authorized_keys /home/ubuntu/.ssh/authorized_keys
else
  rm -f /home/ubuntu/.ssh/authorized_keys
fi
rm -f /tmp/authorized_keys

systemd-tmpfiles --clean
systemd-tmpfiles --remove

rm -rvf /etc/apt/sources.list.d/*

dpkg --list | awk '{ print $2 }' | grep 'linux-headers' | grep -v "$(uname -r)" | xargs -r apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-image-.*-generic' | grep -v "$(uname -r)" | xargs -r apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep 'linux-modules-.*-generic' | grep -v "$(uname -r)" | xargs -r apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep linux-source | xargs -r apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -- '-doc$' | xargs -r apt-get --assume-yes purge;
dpkg --list | awk '{ print $2 }' | grep -E -- '-dev(:[a-z0-9]+)?$' | xargs -r apt-get --assume-yes purge;

for PACKAGE in ansible bash-completion command-not-found command-not-found-data \
  fonts-ubuntu-console fonts-ubuntu-font-family-console friendly-recovery \
  grub-legacy-ec2 installation-report laptop-detect libx11-6 libx11-data libxcb1 \
  libxext6 libxmuu1 motd-news-config popularity-contest ppp pppconfig pppoeconf usbutils xauth; do
  apt-get --assume-yes purge "${PACKAGE}" || true
done

cat <<_EOF_ | cat >> /etc/dpkg/dpkg.cfg.d/excludes
path-exclude=/lib/firmware/*
path-exclude=/usr/share/doc/linux-firmware/*
_EOF_

rm -rf /lib/firmware/*
rm -rf /usr/share/doc/linux-firmware/*

rm -rf /usr/share/doc/*

apt-get --assume-yes autoremove
apt-get --assume-yes clean

find / -name '*.bak' -type f -exec rm -f {} \;
find / -name '*.old' -type f -exec rm -f {} \;
find / -name '*.orig' -type f -exec rm -f {} \;

find /var/cache -type f -exec rm -rf {} \;

find /var/log -type f -exec truncate --size=0 {} \;

find /home -type d -name '.ansible' -exec rm -rf {} \; || true

truncate -s 0 /etc/machine-id

if [ -f /var/lib/dbus/machine-id ] && [ ! -L /var/lib/dbus/machine-id ]; then
  truncate -s 0 /var/lib/dbus/machine-id
fi

rm -rf /tmp/* /var/tmp/*

rm -vf /var/lib/systemd/random-seed

if [ -f /loader/random-seed ]; then
  rm -vf /loader/random-seed
fi

if [ -f /etc/machine-info ]; then
  rm -vf /etc/machine-info
fi

rm -vf /root/.wget-hsts

rm -vf /etc/ssh/*_key /etc/ssh/*_key.pub

mkdir -p /etc/systemd/system/ssh.service.d
cat <<_EOF_ > /etc/systemd/system/ssh.service.d/10-regenerate-host-keys.conf
[Service]
ExecStartPre=
ExecStartPre=/usr/bin/ssh-keygen -A
ExecStartPre=/usr/sbin/sshd -t
_EOF_

rm -vf /root/.*history
