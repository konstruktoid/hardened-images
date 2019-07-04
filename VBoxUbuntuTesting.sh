#!/bin/sh
UBUNTUVERSION="ubuntu-18.04.2"
ISOIMAGE="${UBUNTUVERSION}-hardened-amd64.iso"
ISO="./${ISOIMAGE}"
VMS="ubuntu_64
ubuntu_64_efi
ubuntu_64_efi64"
PORT=2230

if ! command -v VBoxManage 1>/dev/null; then
  echo "VBoxManage required. Exiting."
  exit 1
fi

for VM in ${VMS}; do
  OS_TYPE="Ubuntu_64"

  VBoxManage createhd --filename "${VM}.vdi" --size 50000
  VBoxManage createvm --name "${VM}" --ostype "${OS_TYPE}" --register
  VBoxManage storagectl "${VM}" --name "SATA Controller" --add sata --controller IntelAHCI
  VBoxManage storageattach "${VM}" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "${VM}.vdi"
  VBoxManage storagectl "${VM}" --name "IDE Controller" --add ide
  VBoxManage storageattach "${VM}" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "${ISO}"
  VBoxManage modifyvm "${VM}" --memory 2048 --vram 16

  if echo "${VM}" | grep -q 'efi$'; then
    VBoxManage modifyvm "${VM}" --firmware efi # bios|efi|efi32|efi64
  elif echo "${VM}" | grep -q 'efi64$'; then
    VBoxManage modifyvm "${VM}" --firmware efi64
  else
    VBoxManage modifyvm "${VM}" --firmware bios
  fi

  VBoxManage modifyvm "${VM}" --nic1 nat --nictype1 82545EM
  VBoxManage modifyvm "${VM}" --natpf1 "guestssh,tcp,,${PORT},,22"
  VBoxManage startvm "${VM}"

  PORT=$(( PORT + 1 ))
done

echo "
[i] Remove the ISO after reboot and restart the server again.

[i] Management commands:
    - VBoxManage list vms
    - VBoxManage controlvm VM poweroff
    - VBoxManage unregistervm VM --delete
"

# for b in $(VBoxManage list vms | grep -o 'ubuntu_64.*"' | tr -d '"'); do VBoxManage controlvm "${b}" poweroff ; VBoxManage unregistervm "${b}" --delete; done
