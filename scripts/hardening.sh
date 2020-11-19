#!/bin/bash -eux

export HISTSIZE=0
export HISTFILESIZE=0

apt-get --assume-yes install net-tools procps --no-install-recommends;

git clone https://github.com/konstruktoid/hardening;

cd ./hardening || exit 1

sed -i.bak -e "s/SSH_GRPS=.*/SSH_GRPS='vagrant'/" -e "s/^CHANGEME=.*/CHANGEME='changed'/" ./ubuntu.cfg;

bash ./ubuntu.sh

cd .. || exit 1

rm -rf ./hardening

ufw limit ssh;

sed -i.bak "s/myhostname =.*/myhostname = hardened.local/g" /etc/postfix/main.cf;

find /etc/ -name '*.bak' -exec rm -f {} \;
