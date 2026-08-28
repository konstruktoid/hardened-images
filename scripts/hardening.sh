#!/bin/bash
set -euo pipefail

HARDENING_ROLE_VERSION="${HARDENING_ROLE_VERSION:-v4.4.1}"

BUILD_USERNAME="${BUILD_USERNAME:-ubuntu}"

export ANSIBLE_PRIVATE_ROLE_VARS=true
export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0
export PATH="${PATH}:${HOME}/.local/bin"

apt-get --assume-yes --no-install-recommends --update install git pipx

pipx install ansible-core
pipx ensurepath

REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-/tmp/requirements.yml}"

if [ ! -f "${REQUIREMENTS_FILE}" ]; then
  printf 'error: requirements file not found: %s\n' "${REQUIREMENTS_FILE}" >&2
  exit 1
fi

cat "${REQUIREMENTS_FILE}"

ansible-galaxy install -r "${REQUIREMENTS_FILE}"

cd /tmp

ansible-playbook -i '127.0.0.1,' -c local \
  -e "hardening_role_version=${HARDENING_ROLE_VERSION}" \
  ./local.yml

if id "${BUILD_USERNAME}" > /dev/null 2>&1; then
  chage --maxdays 365 "${BUILD_USERNAME}"
  chage --mindays 1 "${BUILD_USERNAME}"
fi

rm -rvf /tmp/*.yml /tmp/*.cfg /etc/ansible
rm -rf "${HOME}/.ansible"

pipx uninstall-all
rm -rf "${HOME}/.local"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

apt-get --assume-yes purge git pipx open-vm-tools "linux-headers-$(uname -r)" linux-headers-generic
apt-get --assume-yes autoremove
apt-get --assume-yes clean
