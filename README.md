# Hardened Ubuntu server templates

This is a repository containing [Packer](https://www.packer.io/)
templates to create a hardened [Ubuntu](https://releases.ubuntu.com) server.

There are templates available for creating a
- `.ova` package
- [Amazon Machine Image (AMI)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [Azure virtual machine image](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer)
- [Vagrant](https://www.vagrantup.com/) server base box, which includes an
  VMDK file for use in VMWare products.

Ubuntu [Ubuntu 26.04 LTS (Resolute Raccoon)](https://releases.ubuntu.com/resolute/)
is supported.

The Ansible role used to make the server a bit more secure is available in the
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
repository.

The role is installed and configured using [config/local.yml](./config/local.yml).

See [https://www.packer.io/docs/builders](https://www.packer.io/docs/builders)
and [https://www.packer.io/docs/post-processors](https://www.packer.io/docs/post-processors)
on how to rewrite the template if you want to use it for another platforms.

## Usage

### Amazon Web Services

Requires [Packer](https://www.packer.io/) and a
[Amazon Web Services](https://aws.amazon.com/) account.

Ensure that the correct values are set in `ubuntu-aws-vars.json` before
validating the configuration and building the Amazon Machine Image.

```json
{
  "aws_region": "eu-west-3",
  "instance_type": "t3.medium",
  "release": "24.04"
}
```

```sh
packer init -upgrade -var-file ubuntu-aws-vars.json ubuntu-hardened-aws.pkr.hcl
packer validate -var-file ubuntu-aws-vars.json ubuntu-hardened-aws.pkr.hcl
packer build -timestamp-ui -var-file ubuntu-aws-vars.json ubuntu-hardened-aws.pkr.hcl
```

### Azure

Requires [Packer](https://www.packer.io/) and a
[Microsoft Azure](https://portal.azure.com/) account.

Ensure the correct values are set in `ubuntu-azure-vars.json` before
validating the configuration and building the image.

[azure_vars_export](azure_vars_export) is a script that will create or reset
the service principal, and export the necessary environment variables to
authenticate with Azure.

```json
{
  "image_offer": "ubuntu-24_04-lts",
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

### Local files

Requires [Packer](https://www.packer.io/),
[Vagrant](https://www.vagrantup.com/) and
[VirtualBox](https://www.virtualbox.org).

To build the Vagrant boxes, run `bash build_box.sh`.
The script will `git clone https://github.com/chef/bento.git` to a temporary
directory and apply a `.diff` to add the Ansible role.

The generated boxes will be stored in the `output` directory and the
temporary directory removed.

### Verification

There's a [SLSA](https://slsa.dev/) artifact present under the
[slsa action workflow](https://github.com/konstruktoid/hardened-images/actions/workflows/slsa.yml).

## Using the box in a Vagrantfile

```ruby
Vagrant.configure("2") do |config|
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
  end

  config.vm.define "noble" do |noble|
    noble.vm.hostname = "hardened-noble"
    noble.vm.box = "ubuntu-noble/24.04"
    noble.vm.box_url = "file://output/ubuntu-24.04-x86_64.bento-hardened.box"
  end
end
```

## Repository structure

```sh
.
├── azure_vars_export
├── build_box.sh
├── config
│   ├── ansible.cfg
│   ├── bento.diff
│   └── local.yml
├── LICENSE
├── README.md
├── renovate.json
├── scripts
│   ├── aws.sh
│   ├── azure.sh
│   ├── cleanup.sh
│   ├── hardening.sh
│   ├── minimize.sh
│   ├── postproc.sh
│   └── vagrant.sh
├── SECURITY.md
├── ubuntu-aws-vars.json
├── ubuntu-azure-vars.json
├── ubuntu-hardened-aws.pkr.hcl
├── ubuntu-hardened-azure.pkr.hcl
└── Vagrantfile

2 directories, 21 files
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
