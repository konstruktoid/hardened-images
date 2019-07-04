Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |v|
    v.default_nic_type = "Am79C973"
  end

  config.vm.network "private_network", ip:"10.2.3.55"
  config.ssh.insert_key = true
  config.vm.box = "ubuntu/bionic64"
end
