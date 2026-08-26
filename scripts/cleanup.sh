#!/bin/bash
# https://github.com/chef/bento/blob/main/packer_templates/scripts/ubuntu/cleanup_ubuntu.sh

set -euo pipefail

BUILD_USERNAME="${BUILD_USERNAME:-ubuntu}"
BUILD_USER_HOME="$(getent passwd "${BUILD_USERNAME}" | cut -d: -f6)"
BUILD_USER_HOME="${BUILD_USER_HOME:-/home/${BUILD_USERNAME}}"

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

purge_matching() {
  local pattern="$1"
  local keep="${2:-}"
  local packages

  packages="$(dpkg-query --show --showformat='${Package}\n' \
    | grep -E -- "${pattern}" || true)"

  if [ -n "${packages}" ] && [ -n "${keep}" ]; then
    packages="$(printf '%s\n' "${packages}" | grep -F -v -- "${keep}" || true)"
  fi

  [ -n "${packages}" ] || return 0

  # shellcheck disable=SC2086
  apt-get --assume-yes purge ${packages}
}

if [ -s /tmp/authorized_keys ]; then
  install -d -m 0700 -o "${BUILD_USERNAME}" -g "${BUILD_USERNAME}" "${BUILD_USER_HOME}/.ssh"
  install -m 0600 -o "${BUILD_USERNAME}" -g "${BUILD_USERNAME}" \
    /tmp/authorized_keys "${BUILD_USER_HOME}/.ssh/authorized_keys"
else
  rm -f "${BUILD_USER_HOME}/.ssh/authorized_keys"
fi
rm -f /tmp/authorized_keys

systemd-tmpfiles --clean
systemd-tmpfiles --remove

rm -rvf /etc/apt/sources.list.d/*

KERNEL_RELEASE="$(uname -r)"

purge_matching 'linux-headers' "${KERNEL_RELEASE}"
purge_matching 'linux-image-.*-generic' "${KERNEL_RELEASE}"
purge_matching 'linux-modules-.*-generic' "${KERNEL_RELEASE}"
purge_matching 'linux-source'
purge_matching '-doc$'
purge_matching '-dev(:[a-z0-9]+)?$'

for PACKAGE in ansible bash-completion command-not-found command-not-found-data \
  fonts-ubuntu-console fonts-ubuntu-font-family-console friendly-recovery \
  grub-legacy-ec2 installation-report laptop-detect libx11-6 libx11-data libxcb1 \
  libxext6 libxmuu1 motd-news-config popularity-contest ppp pppconfig pppoeconf usbutils xauth; do
  apt-get --assume-yes purge "${PACKAGE}" || true
done

cat >> /etc/dpkg/dpkg.cfg.d/excludes <<'_EOF_'
path-exclude=/lib/firmware/*
path-exclude=/usr/share/doc/linux-firmware/*
_EOF_

rm -rf /lib/firmware/*
rm -rf /usr/share/doc/linux-firmware/*
rm -rf /usr/share/doc/*

apt-get --assume-yes autoremove
apt-get --assume-yes clean

find / -xdev -type f \( -name '*.bak' -o -name '*.old' -o -name '*.orig' \) -delete

find /var/cache -xdev -type f -delete
find /var/log -xdev -type f -exec truncate --size=0 {} +

find /home -xdev -type d -name '.ansible' -prune -exec rm -rf {} +

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
cat > /etc/systemd/system/ssh.service.d/10-regenerate-host-keys.conf <<'_EOF_'
[Service]
ExecStartPre=
ExecStartPre=/usr/bin/ssh-keygen -A
ExecStartPre=/usr/sbin/sshd -t
_EOF_

rm -vf /root/.*history
