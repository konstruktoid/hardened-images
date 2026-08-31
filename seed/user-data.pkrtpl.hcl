#cloud-config
hostname: ${hostname}
create_hostname_file: true

# Packer provisions over the ephemeral key, so the default account never has to accept a password
# over SSH during the build. The shipped image's setting comes from the hardening role instead.
ssh_pwauth: false

users:
  - name: ${username}
    shell: /bin/bash
    groups:
      - adm
      - sudo
    lock_passwd: false
    hashed_passwd: "${password_hash}"
    sudo: "ALL=(ALL:ALL) ALL"
    ssh_authorized_keys: ${authorized_keys_json}

growpart:
  mode: auto
  devices:
    - /

package_update: true
package_upgrade: true
