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
