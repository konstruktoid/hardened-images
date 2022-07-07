#!/bin/bash -eux
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html

export DEBIAN_FRONTEND=noninteractive
export HISTSIZE=0
export HISTFILESIZE=0

apt-get --assume-yes update
apt-get --assume-yes --reinstall install snapd
systemctl enable --now snapd

snap install amazon-ssm-agent --classic
snap start amazon-ssm-agent

systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service

systemd-tmpfiles --clean
systemd-tmpfiles --remove

apt-get --assume-yes update

apt-get --assume-yes autoremove;
apt-get --assume-yes clean;

find /var/cache -type f -exec rm -rvf {} \;

find /var/log -type f -exec truncate --size=0 {} \;

truncate -s 0 /etc/machine-id

rm -rvf /tmp/* /var/tmp/*

rm -vf /var/lib/systemd/random-seed

rm -vf /root/.wget-hsts

rm -vf /etc/ssh/*_key /etc/ssh/*_key.pub

rm -vf ~/.*history

export HISTSIZE=0
