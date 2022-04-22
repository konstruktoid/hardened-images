Vagrant.configure("2") do |config|
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
  end

  config.vm.define "hardened" do |hardened|
    hardened.vm.hostname = "hardened-focal"
    hardened.vm.box = "ubuntu-focal/20.04"
    hardened.vm.box_url = "file://output/ubuntu-20.04-hardened-server.box"
  end
end
