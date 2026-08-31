#cloud-config
hostname: ${hostname}
create_hostname_file: true

ssh_pwauth: true

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
