#!/bin/bash
set -eux -o pipefail

shellcheck -x -s bash -f gcc scripts/*

BASE_DIR="$(pwd)"
GIT_CLONE_DIR="$(mktemp --directory -p /var/tmp bento.XXXXXX)"
BUILD_ISOS="virtualbox-iso.vm" # "virtualbox-iso.vm,vmware-iso.vm,qemu.vm"

mkdir -p "${BASE_DIR}/output"

git clone https://github.com/chef/bento.git "${GIT_CLONE_DIR}"

cp -r "${BASE_DIR}/scripts/hardening.sh" "${GIT_CLONE_DIR}/packer_templates/scripts/"
cp -r "${BASE_DIR}/config/" "${GIT_CLONE_DIR}/packer_templates/config"

cd "${GIT_CLONE_DIR}" || exit 1

git apply ./packer_templates/config/bento.diff

packer init -upgrade ./packer_templates
find . -name 'ubuntu-2[4-8].*-x86_64.pkrvars.hcl' | while read -r template; do
  packer build -only="${BUILD_ISOS}" -var-file="${template}" ./packer_templates
  box_name="$(basename "${template}" | awk -F '-' '{print $2}')"
  find . -name "ubuntu-${box_name}-*.box" | while read -r box; do
    mod_name="$(basename "$box" | sed 's/virtualbox/bento-hardened/g')"
    mv -v "${box}" "${BASE_DIR}/output/${mod_name}"
  done
done

cd "${BASE_DIR}" || exit 1

echo "Vagrant.configure(\"2\") do |config|
  config.vm.provider \"virtualbox\" do |vb|
    vb.customize [\"modifyvm\", :id, \"--uart1\", \"0x3F8\", \"4\"]
    vb.customize [\"modifyvm\", :id, \"--uartmode1\", \"disconnected\"]
  end

  hosts = [" | tee ./Vagrantfile

find ./output/ -type f -name '*.box' | while read -r b; do
  box_hostname="$(basename "${b}" | awk -F '-' '{print "hardened-"$1"-"$2}' | tr -d '.')"
  box_name="$(basename "${b}" | sed -e 's/-x.*//g' -e 's/-/\//g')"

echo "    { name: \"${box_hostname}\", box: \"hardened-${box_name}\", box_url: \"file://${b}\" }" | sed 's/\.\///g' | tee -a ./Vagrantfile
done

echo "  ]

  hosts.each do |host|
    config.vm.define host[:name] do |node|
      node.ssh.insert_key = true
      node.ssh.key_type = \"ed25519\"
      node.vm.boot_timeout = 600
      node.vm.box = host[:box]
      node.vm.box_url = host[:box_url]
      node.vm.hostname = host[:name]
    end
  end
end" | tee -a ./Vagrantfile

rm -rf "${GIT_CLONE_DIR}"
