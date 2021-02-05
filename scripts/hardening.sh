#!/bin/bash -eux

export HISTSIZE=0
export HISTFILESIZE=0

apt-get --assume-yes install net-tools procps --no-install-recommends;

git clone https://github.com/konstruktoid/hardening;

cd ./hardening || exit 1

sed -i.bak -e "s/SSH_GRPS=.*/SSH_GRPS='vagrant'/" -e "s/^CHANGEME=.*/CHANGEME='changed'/" ./ubuntu.cfg;
sed -i.bak 's/.*f_aide_/# f_aide_/g' ./ubuntu.sh;

bash ./ubuntu.sh

cd .. || exit 1

rm -rf ./hardening

sed -i.bak 's/^/# /g' /etc/default/grub.d/99-hardening-lockdown.cfg
sed -i.bak "s/myhostname =.*/myhostname = hardened.local/g" /etc/postfix/main.cf;
sed -i.bak '/fat/d' /etc/modprobe.d/disable*;

ufw allow ssh;

update-grub
systemctl restart sshd

find /etc -name '*.bak' -exec rm -f {} \;

if id vagrant; then
  chage --maxdays 365 vagrant
  chage --mindays 1 vagrant
fi
