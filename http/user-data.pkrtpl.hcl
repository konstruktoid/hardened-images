#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    version: 2
    ethernets:
      any-en:
        match:
          name: "en*"
        dhcp4: true
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys: ${authorized_keys_json}
  storage:
    layout:
      name: direct
  identity:
    hostname: ${hostname}
    username: ${username}
    password: ${password_hash}
  updates: security
  packages: []
