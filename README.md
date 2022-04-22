# Hardened Vagrant Ubuntu 20.04 server base box

`hardening-geniso` is a repository containing a [Packer](https://www.packer.io/)
template to create a hardened [Vagrant](https://www.vagrantup.com/)
[Ubuntu](https://releases.ubuntu.com/focal/) server base box and a `.ova`
package.

The Ansible role used to make the server a bit more secure is available in the
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
repository.

The role is installed and configured using [config/local.yml](./config/local.yml).

See [https://www.packer.io/docs/builders](https://www.packer.io/docs/builders)
and [https://www.packer.io/docs/post-processors](https://www.packer.io/docs/post-processors)
on how to rewrite the template if you want to use it for another platforms.

## Building the box

### Requirements

- [Packer](https://www.packer.io/)
- [VirtualBox](https://www.virtualbox.org)

#### Using `packer`

To build the box, run `bash build_box.sh`.

The script will validate the `Packer` template, the `Vagrantfile` and the shell
scripts. It will then remove any old versions of the box before generating a new
one.

`packer build -force -timestamp-ui -var-file <var-file> ubuntu-hardened-packer.pkr.hcl`
is the `packer` command used if all files are valid.

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
    focal.vm.box = "ubuntu-hardened/20.04"
    focal.vm.box_url = "file://output/ubuntu-20.04-hardened-server.box"
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
├── http
│   ├── meta-data
│   └── user-data
├── output
│   ├── ubuntu-20.04-hardened-server.box
│   ├── ubuntu-20.04-hardened-server.ova
│   └── ubuntu-20.04-hardened-server.sha256
├── renovate.json
├── scripts
│   ├── cleanup.sh
│   ├── hardening.sh
│   ├── minimize.sh
│   ├── postproc.sh
│   └── vagrant.sh
├── ubuntu-20.04-vars.json
├── ubuntu-22.04-vars.json
└── ubuntu-hardened-packer.pkr.hcl

3 directories, 18 files
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
