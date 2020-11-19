# Hardened Vagrant Ubuntu 20.04 server base box

`hardening-geniso` is a repository containing a [Packer](https://www.packer.io/)
template to create a hardened [Vagrant](https://www.vagrantup.com/)
[Ubuntu 20.04](http://www.releases.ubuntu.com/20.04/) server base box, and
a OVF package.

The script used to make the server a bit more secure is available in the
[konstruktoid/hardening](https://github.com/konstruktoid/hardening) repository.

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

`packer build -force -timestamp-ui ubuntu-hardened-20.04-packer.json` is the
`packer` command used if all files are valid.

## Using the box in a Vagrantfile

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu-hardened/20.04"
  config.vm.box_url = "file://output/ubuntu-20.04-hardened-server.box"
end
```

A more advanced example:

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
    focal.vm.synced_folder ".", "/vagrant", disabled: true
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
│   ├── ubuntu-20.04-hardened-server-timestamp-disk001.vmdk
│   ├── ubuntu-20.04-hardened-server-timestamp.mf
│   ├── ubuntu-20.04-hardened-server-timestamp.ovf
│   ├── ubuntu-20.04-hardened-server.box
│   └── ubuntu-20.04-hardened-server.sha256
├── scripts
│   ├── cleanup.sh
│   ├── hardening.sh
│   ├── postproc.sh
│   └── vagrant.sh
└── ubuntu-hardened-20.04-packer.json

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
