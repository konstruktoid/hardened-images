#!/bin/sh -eux
# https://github.com/chef/bento/blob/master/packer_templates/ubuntu/scripts/cleanup.sh
# https://github.com/chef/bento/blob/master/packer_templates/_common/minimize.sh

export HISTSIZE=0
export HISTFILESIZE=0

count=$(df --sync -kP / | tail -n1  | awk -F ' ' '{print $4}')
count=$((count-1))

dd if=/dev/zero of=/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /whitespace

dd if=/dev/zero of=/tmp/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /tmp/whitespace

count=$(df --sync -kP /boot | tail -n1 | awk -F ' ' '{print $4}')
count=$((count-1))
dd if=/dev/zero of=/boot/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /boot/whitespace

set +e
swapuuid="$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)";
case "$?" in
    2|0) ;;
    *) exit 1 ;;
esac
set -e

if [ "x${swapuuid}" != "x" ]; then
    swappart="$(readlink -f "/dev/disk/by-uuid/$swapuuid")";
    /sbin/swapoff "$swappart" || true;
    dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? is suppressed";
    /sbin/mkswap -U "$swapuuid" "$swappart";
fi

sync;
