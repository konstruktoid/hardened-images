#!/bin/bash
#
# Thanks for the groundwork:
# https://nathanpfry.com/how-to-customize-an-ubuntu-installation-disc/
#

UBUNTUVERSION="ubuntu-18.04.4"
CUSTOMNAME="${UBUNTUVERSION}-hardened-amd64.iso"
VOLID="UBUNTUHARDENED"
ISOIMAGE="${UBUNTUVERSION}-live-server-amd64.iso"
ISOURL="http://releases.ubuntu.com/bionic/${ISOIMAGE}"
SHA256="73b8d860e421000a6e35fdefbb0ec859b9385b0974cf8089f5d70a87de72f6b9"
# SHASUM="http://releases.ubuntu.com/bionic/SHA256SUMS"

if [ "$(id -u)" -ne 0 ]; then
  echo "[e] Not enough privileges. Exiting."
  exit 1
fi

apt-get -q=2 update

for p in cpio fakeroot gunzip shellcheck xorriso; do
  if ! command -v "$p"; then
    echo "[i] $p required. Installing."
    apt-get --assume-yes install "$p"
  fi
done

if ! shellcheck -x -s bash -f gcc ./*.sh config/*.sh; then
  echo "[e] shellcheck failed. Exiting."
  exit 1
fi

if [ -f "./${ISOIMAGE}" ]; then
  if [ "$(sha256sum ./${ISOIMAGE} | awk '{print $1}')" = "$SHA256" ]; then
    echo
    echo "[i] Checksum for ${ISOIMAGE} matches."
    echo
  else
    echo
    echo "[e] Checksum for ${ISOIMAGE} don't match."
    exit 1
  fi
else
  echo
  echo "[e] No ${ISOIMAGE} present."
  echo "[i] Download ${ISOURL}."
  exit 1
fi

mkdir ~/custom-img
cp -R ./config/ ~/custom-img/

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
cp -R ./config/ edit/usr/local/bin/hardening-config

echo
echo "[i] chrooting."
echo

chroot edit /bin/bash <<"EOT"

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
apt-get --assume-yes --with-new-pkgs upgrade
apt-get --assume-yes clean
apt-get --assume-yes autoremove

echo "ONBOOT=0" > /etc/default/hardening-config

chown root:root /usr/local/bin/hardening-config/config.sh
chmod 0755 /usr/local/bin/hardening-config/config.sh
cp /usr/local/bin/hardening-config/hardening-config.service /etc/systemd/system/
chmod 0644 /etc/systemd/system/hardening-config.service
systemctl enable /etc/systemd/system/hardening-config.service

/lib/systemd/systemd-random-seed load
/lib/systemd/systemd-random-seed save

history -w
history -c

rm -rf /tmp/* ~/.bash_history /var/tmp/*
rm /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts

EOT

umount edit/dev

echo
echo "[i] chroot work completed."
echo

chmod +w extract/casper/filesystem.manifest

# shellcheck disable=SC2016
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' |  tee extract/casper/filesystem.manifest

cp extract/casper/filesystem.manifest extract/casper/filesystem.manifest-desktop
sed -i '/ubiquity/d' extract/casper/filesystem.manifest-desktop
sed -i '/casper/d' extract/casper/filesystem.manifest-desktop


mksquashfs edit extract/casper/filesystem.squashfs -b 1048576

printf "%s" "$(du -sx --block-size=1 edit | cut -f1)" |  tee extract/casper/filesystem.size

cd extract || exit 1
rm md5sum.txt
find . -type f -print0 |  xargs -0 md5sum | grep -v isolinux/boot.cat |  tee md5sum.txt

dd if=~/custom-img/${ISOIMAGE} bs=512 count=1 of=isolinux/isohdpfx.bin

xorriso -as mkisofs -b isolinux/isolinux.bin -isohybrid-mbr isolinux/isohdpfx.bin \
 -volid "$VOLID" -publisher "$(id -un)-$(hostname -s)" \
 -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
 -isohybrid-gpt-basdat -o  "../${CUSTOMNAME}" .

cd ~/custom-img || exit 1
umount ./mnt || exit 1
rm -rf ./edit ./extract ./mnt ./config
sha256sum "./${CUSTOMNAME}" > SHA256SUM
