#!/bin/bash
# https://github.com/chef/bento/blob/main/packer_templates/scripts/ubuntu/cleanup_ubuntu.sh

set -euo pipefail

BUILD_USERNAME="${BUILD_USERNAME:-ubuntu}"
BUILD_USER_HOME="$(getent passwd "${BUILD_USERNAME}" | cut -d: -f6)"
BUILD_USER_HOME="${BUILD_USER_HOME:-/home/${BUILD_USERNAME}}"
POWEROFF_AFTER_CLEANUP="${POWEROFF_AFTER_CLEANUP:-false}"

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

filter_lines() {
  local status=0

  grep "$@" || status="$?"

  [ "${status}" -le 1 ] || return "${status}"
}

purge_matching() {
  local pattern="$1"
  local keep="${2:-}"
  local installed matched
  local packages=()

  installed="$(dpkg-query --show --showformat='${Package}\n')"
  matched="$(printf '%s\n' "${installed}" | filter_lines -E -- "${pattern}")"

  if [ -n "${matched}" ] && [ -n "${keep}" ]; then
    matched="$(printf '%s\n' "${matched}" | filter_lines -F -v -- "${keep}")"
  fi

  [ -n "${matched}" ] || return 0

  mapfile -t packages <<< "${matched}"

  apt-get --assume-yes purge "${packages[@]}"
}

if [ -s /tmp/authorized_keys ]; then
  install -d -m 0700 -o "${BUILD_USERNAME}" -g "${BUILD_USERNAME}" "${BUILD_USER_HOME}/.ssh"
  install -m 0600 -o "${BUILD_USERNAME}" -g "${BUILD_USERNAME}" \
    /tmp/authorized_keys "${BUILD_USER_HOME}/.ssh/authorized_keys"
else
  rm -f "${BUILD_USER_HOME}/.ssh/authorized_keys"
fi
rm -f /tmp/authorized_keys
rm -rf "${BUILD_USER_HOME}/.ssh/agent"
rm -rf /root/.ssh

systemd-tmpfiles --clean
systemd-tmpfiles --remove

find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list' -print -delete

KERNEL_RELEASE="$(uname -r)"

purge_matching 'linux-headers' "${KERNEL_RELEASE}"
purge_matching 'linux-image-.*-generic' "${KERNEL_RELEASE}"
purge_matching 'linux-modules-.*-generic' "${KERNEL_RELEASE}"
purge_matching 'linux-source'
purge_matching '-doc$'
purge_matching '-dev(:[a-z0-9]+)?$'

for PACKAGE in ansible bash-completion command-not-found command-not-found-data curl \
  fonts-ubuntu-console fonts-ubuntu-font-family-console friendly-recovery \
  fwupd grub-legacy-ec2 installation-report laptop-detect libx11-6 libx11-data libxcb1 \
  libxext6 libxmuu1 linux-perf man-db manpages motd-news-config popularity-contest ppp pppconfig pppoeconf \
  python3-boto3 python3-botocore snapd usbutils \
  wget xauth; do
  apt-get --assume-yes purge "${PACKAGE}" || true
done

cat >> /etc/dpkg/dpkg.cfg.d/excludes <<'_EOF_'
path-exclude=/lib/firmware/*
path-exclude=/usr/share/doc/linux-firmware/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/en*
path-include=/usr/share/locale/locale.alias
path-exclude=/usr/share/man/*
_EOF_

rm -rf /lib/firmware/*
rm -rf /usr/share/doc/linux-firmware/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*

find /usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name 'en*' -exec rm -rf {} +

rm -rf /var/lib/snapd /var/cache/snapd /snap "${BUILD_USER_HOME}/snap" /root/snap

apt-get --assume-yes --purge autoremove
apt-get --assume-yes clean

dpkg-query --show --showformat='${db:Status-Abbrev}\t${Package}\n' \
  | awk -F'\t' '$1 ~ /^rc/ { print $2 }' \
  | xargs --no-run-if-empty dpkg --purge

find /var/lib/apt/lists -maxdepth 1 -type f ! -name lock -delete
rm -f /var/lib/dpkg/status-old /var/lib/dpkg/available-old

find / -xdev -type f \
  \( -name '*.bak' -o -name '*.old' -o -name '*.orig' -o -name '*~' \
  -o -name '*.dpkg-old' -o -name '*.dpkg-new' -o -name '*.dpkg-dist' \
  -o -name '*.dpkg-bak' -o -name '*.dpkg-tmp' \
  -o -name '*.ucf-old' -o -name '*.ucf-new' -o -name '*.ucf-dist' \
  -o -name '*.rej' -o -name '*.swp' -o -name '*.swo' \) -delete

find /var/cache -xdev -type f -delete
find /var/log -xdev -type f -exec truncate --size=0 {} +

find /home -xdev -type d -name '.ansible' -prune -exec rm -rf {} +

find /root /home -xdev -maxdepth 2 -type d -name '.cache' -exec rm -rf {} +

journalctl --rotate
journalctl --vacuum-time=1s
rm -rf /var/log/journal/*

rm -f /etc/netplan/50-cloud-init.yaml
install -m 0600 /dev/null /etc/netplan/01-dhcp-all-ethernets.yaml
cat > /etc/netplan/01-dhcp-all-ethernets.yaml <<'_EOF_'
network:
  version: 2
  ethernets:
    all-ethernets:
      match:
        name: "en*"
      dhcp4: true
      dhcp6: true
_EOF_

if command -v cloud-init > /dev/null 2>&1; then
  cloud-init clean --logs --seed
fi

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

fstrim -av || printf 'warning: fstrim did not complete\n' >&2

if [ "${POWEROFF_AFTER_CLEANUP}" = "true" ]; then
  systemd-run --collect --unit=packer-poweroff --on-active=30 \
    bash -c 'find /var/log -xdev -type f -exec truncate --size=0 {} +;
      rm -rf /var/log/journal/*;
      rm -f /var/lib/systemd/random-seed;
      systemctl poweroff'
fi
