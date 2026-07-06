#!/bin/bash -eux
# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic
# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

echo "GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE_LINUX console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300\"" | tee /etc/default/grub.d/99-azure.cfg

update-grub

apt-get --assume-yes --update upgrade

if [ ! -f /usr/bin/python ]; then
  ln -s "$(which python3)" /usr/bin/python
fi

apt-get --assume-yes install walinuxagent

sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf
