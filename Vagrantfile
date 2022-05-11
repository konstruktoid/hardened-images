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
