#!/bin/bash
# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic
# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

tee /etc/default/grub.d/99-azure.cfg <<'_EOF_'
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300"
_EOF_

update-grub

apt-get --assume-yes --update upgrade

if [ ! -e /usr/bin/python ]; then
  ln -s "$(command -v python3)" /usr/bin/python
fi

apt-get --assume-yes install walinuxagent

sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf
