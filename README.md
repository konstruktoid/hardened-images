# Hardened Ubuntu server templates

This is a repository containing [Packer](https://www.packer.io/)
templates to create a hardened [Ubuntu](https://releases.ubuntu.com) server.

There are templates available for creating a
- [Vagrant](https://www.vagrantup.com/) server base box
- `.ova` package
- [Amazon Machine Image (AMI)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)

[20.04 LTS (Focal Fossa)](https://releases.ubuntu.com/focal/) and
[22.04 LTS (Jammy Jellyfish)](https://releases.ubuntu.com/jammy/) are supported.

The Ansible role used to make the server a bit more secure is available in the
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
repository.

The role is installed and configured using [config/local.yml](./config/local.yml).

See [https://www.packer.io/docs/builders](https://www.packer.io/docs/builders)
and [https://www.packer.io/docs/post-processors](https://www.packer.io/docs/post-processors)
on how to rewrite the template if you want to use it for another platforms.

## Usage

### Using `packer`

#### Local files

Requires [Packer](https://www.packer.io/),
[Vagrant](https://www.vagrantup.com/) and
[VirtualBox](https://www.virtualbox.org).

To build the Vagrant boxes and the `.ova` files , run `bash build_box.sh`.

The script will validate the `Packer` template, the `Vagrantfile` and the shell
scripts. It will then remove any old versions of the box before generating a new
one.

`packer build -force -timestamp-ui -var-file <var-file> ubuntu-hardened-box.pkr.hcl`
is the `packer` command used if all files are valid.

#### Amazon Web Services

Requires [Packer](https://www.packer.io/) and a
[Amazon Web Services](https://aws.amazon.com/) account.

Ensure that the correct `release` and `aws_region` are set in
`ubuntu-aws-vars.json` before validating the configuration and building the
Amazon Machine Image.

```sh
packer validate -var-file ubuntu-aws-vars.json ubuntu-hardened-aws.pkr.hcl
packer build -timestamp-ui -var-file ubuntu-aws-vars.json ubuntu-hardened-aws.pkr.hcl
```

### Verification

There's a [SLSA](https://slsa.dev/) artifact present under the
[slsa action workflow](https://github.com/konstruktoid/hardening-geniso/actions/workflows/slsa.yml).

Verification of the built local files can be done using
`sha256sum -c ubuntu-hardened-server.sha256` or using similar commands.

## Using the box in a Vagrantfile

### Local box

```ruby
Vagrant.configure("2") do |config|
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
  end

  config.vm.define "focal" do |focal|
    focal.vm.hostname = "hardened-focal"
    focal.vm.box = "ubuntu-focal/20.04"
    focal.vm.box_url = "file://output/ubuntu-20.04.4-hardened-server.box"
  end

  config.vm.define "jammy" do |jammy|
    jammy.vm.hostname = "hardened-jammy"
    jammy.vm.box = "ubuntu-jammy/22.04"
    jammy.vm.box_url = "file://output/ubuntu-22.04-hardened-server.box"
  end
end
```

### Remote box

```ruby
Vagrant.configure("2") do |config|
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
  end

  config.vm.define "focal_remote" do |focal_remote|
    focal_remote.vm.box = "konstruktoid/focal-hardened"
    focal_remote.vm.hostname = "focalremote"
  end
end
```

## Repository structure

```sh
.
├── LICENSE
├── README.md
├── Vagrantfile
├── build_box.sh
├── config
│   ├── ansible.cfg
│   └── local.yml
├── http
│   ├── meta-data
│   └── user-data
├── output
│   ├── ubuntu-20.04.4-hardened-server.box
│   ├── ubuntu-20.04.4-hardened-server.ova
│   ├── ubuntu-22.04-hardened-server.box
│   ├── ubuntu-22.04-hardened-server.ova
│   └── ubuntu-hardened-server.sha256
├── renovate.json
├── scripts
│   ├── aws.sh
│   ├── cleanup.sh
│   ├── hardening.sh
│   ├── minimize.sh
│   ├── postproc.sh
│   └── vagrant.sh
├── ubuntu-20.04-vars.json
├── ubuntu-22.04-vars.json
├── ubuntu-aws-vars.json
├── ubuntu-hardened-aws.pkr.hcl
└── ubuntu-hardened-box.pkr.hcl

4 directories, 25 files
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
