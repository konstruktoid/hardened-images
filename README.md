# Hardened Ubuntu server templates

This is a repository containing [Packer](https://www.packer.io/)
templates to create a hardened [Ubuntu](https://releases.ubuntu.com) server.

There are templates available for creating a
- `.ova` package
- [Azure virtual machine image](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer)
- [QEMU](https://www.qemu.org/) `.qcow2` disk image

[Ubuntu 26.04 LTS (Resolute Raccoon)](https://releases.ubuntu.com/resolute/)
is supported.

The Ansible role used to make the server a bit more secure is available in the
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
repository.

The role is installed and configured using [config/local.yml](./config/local.yml).

See [https://www.packer.io/docs/builders](https://www.packer.io/docs/builders)
and [https://www.packer.io/docs/post-processors](https://www.packer.io/docs/post-processors)
on how to rewrite the template if you want to use it for another platforms.

## Usage

### Azure

Requires [Packer](https://www.packer.io/) and a
[Microsoft Azure](https://portal.azure.com/) account.

Ensure the correct values are set in `ubuntu-azure-vars.json` before
validating the configuration and building the image.

[azure_vars_export](azure_vars_export) is a script that will create or reset
the service principal, export the necessary environment variables to
authenticate with Azure, and detect the caller's public IP address so the
build VM's network security group only allows inbound SSH from that address.

```json
{
  "image_offer": "ubuntu-26_04-lts",
  "image_sku": "server",
  "principal_name": "PackerPrincipal",
  "resource_group": "PackerGroup",
  "vm_size": "Standard_D2s_v3"
}
```

```sh
packer init -upgrade -var-file ubuntu-azure-vars.json ubuntu-hardened-azure.pkr.hcl
packer validate -var-file ubuntu-azure-vars.json ubuntu-hardened-azure.pkr.hcl
packer build -timestamp-ui -var-file ubuntu-azure-vars.json ubuntu-hardened-azure.pkr.hcl
```

### Local qcow2 image

Requires [Packer](https://www.packer.io/), [QEMU](https://www.qemu.org/) and
[OVMF](https://github.com/tianocore/tianocore.github.io/wiki/OVMF).

To build the image, run `bash build_box.sh`. The script generates a throwaway
SSH keypair, then builds [ubuntu-hardened-qemu.pkr.hcl](./ubuntu-hardened-qemu.pkr.hcl),
a self-contained template with no external dependencies: Packer boots the
official Ubuntu 26.04 live-server ISO in QEMU and installs it unattended
using the [autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
configuration in [http/user-data.pkrtpl](./http/user-data.pkrtpl).

Once the build completes, an SBOM of the image is generated with
[Syft](https://github.com/anchore/syft) using
[scripts/sbom.sh](./scripts/sbom.sh).

The generated `.qcow2` disk image, along with its SPDX (`.spdx.json`) and
CycloneDX (`.cdx.json`) SBOM files and a `CHECKSUMS` file, are stored in a
timestamped subdirectory under `output`.

By default the image ships with a single `ubuntu` account (password
`ubuntu`, see `var.password`/`var.password_hash`) and no persisted SSH keys.
Pass your own public keys to keep them installed in the built image:

```sh
bash build_box.sh -var 'ssh_authorized_keys=["ssh-ed25519 AAAA... you@example.com"]'
```

Extra arguments given to `build_box.sh` are passed through to `packer build`.
The ephemeral keypair Packer itself uses to provision the image is always
stripped by [scripts/cleanup.sh](./scripts/cleanup.sh) before the build
finishes.

### Verification

There's a [SLSA](https://slsa.dev/) artifact present under the
[slsa action workflow](https://github.com/konstruktoid/hardened-images/actions/workflows/slsa.yml).

## Using the qcow2 image

Boot the image built by [build_box.sh](./build_box.sh) with QEMU, using the
same OVMF UEFI firmware as the build, and forward a local port to the guest's
SSH server:

```sh
cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/OVMF_VARS.fd

qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd \
  -drive if=virtio,format=qcow2,file=./output/<build>/<build>.qcow2 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -display none -serial mon:stdio \
  -device virtio-net-pci,netdev=net0
```

Replace `./output/<build>/<build>.qcow2` with the actual `.qcow2` path
produced under the `output` directory, and drop `-cpu host,accel=kvm` if
hardware virtualization isn't available on the host.

Once booted, connect over SSH as the `ubuntu` user, either with a key you
passed via `ssh_authorized_keys` or with the password `ubuntu`
(see [Local qcow2 image](#local-qcow2-image)):

```sh
ssh -p 2222 -o StrictHostKeyChecking=no ubuntu@localhost
```

## Repository structure

```sh
.
├── azure_vars_export
├── build_box.sh
├── config
│   ├── ansible.cfg
│   └── local.yml
├── http
│   ├── meta-data
│   └── user-data.pkrtpl
├── LICENSE
├── README.md
├── scripts
│   ├── azure.sh
│   ├── cleanup.sh
│   ├── hardening.sh
│   └── sbom.sh
├── SECURITY.md
├── ubuntu-azure-vars.json
├── ubuntu-hardened-azure.pkr.hcl
└── ubuntu-hardened-qemu.pkr.hcl

3 directories, 16 files
```

## Contributing

Do you want to contribute? Great! Contributions are always welcome,
no matter how large or small. If you found something odd, feel free to submit a
issue, improve the code by creating a pull request, or by
[sponsoring this project](https://github.com/sponsors/konstruktoid).

## License

Apache License Version 2.0

## Author Information

[https://github.com/konstruktoid](https://github.com/konstruktoid "github.com/konstruktoid")
