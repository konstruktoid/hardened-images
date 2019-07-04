#!/bin/bash
# https://nathanpfry.com/how-to-customize-an-ubuntu-installation-disc/

UBUNTUVERSION="ubuntu-18.04.2"
CUSTOMNAME="${UBUNTUVERSION}-hardened-amd64.iso"
VOLID="UBUNTUHARDENED"
ISOIMAGE="${UBUNTUVERSION}-live-server-amd64.iso"
ISOURL="http://releases.ubuntu.com/bionic/${ISOIMAGE}"
SHA256="ea6ccb5b57813908c006f42f7ac8eaa4fc603883a2d07876cf9ed74610ba2f53"
# SHASUM="http://releases.ubuntu.com/bionic/SHA256SUMS"

for p in cpio fakeroot gunzip xorriso; do
  if ! command -v "$p"; then
    echo "$p required."
    apt-get -y install "$p"
  fi
done

if [ -f "./${ISOIMAGE}" ]; then
  if [ "$(sha256sum ./${ISOIMAGE} | awk '{print $1}')" = "$SHA256" ]; then
    echo "Checksum for ${ISOIMAGE} matches."
  else
    echo "Checksum for ${ISOIMAGE} don't match."
    exit 1
  fi
else
  echo "No ${ISOIMAGE} present."
  echo "${ISOURL}"
  exit 1
fi

mkdir ~/custom-img

cp "${ISOIMAGE}" ~/custom-img
cd ~/custom-img || exit 1

mkdir mnt
mkdir extract

mount -o loop "${ISOIMAGE}" mnt
rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract
unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit
cp /etc/resolv.conf edit/etc/
mount --bind /dev/ edit/dev

echo
echo "chrooting."
chroot edit /bin/bash <<"EOT"

#
# Working inside chroot
#

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C
dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
dpkg --add-architecture i386

apt-get update
apt-get --assume-yes upgrade
apt-get autoremove
apt-get autoclean

rm -rf /tmp/* ~/.bash_history
rm /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts
EOT

umount edit/dev

echo "chroot work completed."
echo

chmod +w extract/casper/filesystem.manifest

# shellcheck disable=SC2016
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' |  tee extract/casper/filesystem.manifest

cp extract/casper/filesystem.manifest extract/casper/filesystem.manifest-desktop
sed -i '/ubiquity/d' extract/casper/filesystem.manifest-desktop
sed -i '/casper/d' extract/casper/filesystem.manifest-desktop


mksquashfs edit extract/casper/filesystem.squashfs -b 1048576

printf "%s" "$( du -sx --block-size=1 edit | cut -f1)" |  tee extract/casper/filesystem.size

cd extract || exit 1
 rm md5sum.txt
find . -type f -print0 |  xargs -0 md5sum | grep -v isolinux/boot.cat |  tee md5sum.txt

dd if=~/custom-img/${ISOIMAGE} bs=512 count=1 of=isolinux/isohdpfx.bin

xorriso -as mkisofs -b isolinux/isolinux.bin -isohybrid-mbr isolinux/isohdpfx.bin \
 -volid "$VOLID" -publisher "$(id -un)-$(hostname -s)" \
 -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
 -isohybrid-gpt-basdat -o  "../${CUSTOMNAME}" .

# genisoimage -D -r -V "${UBUNTUVERSION}-hardened" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "../${CUSTOMNAME}" .
