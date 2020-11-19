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
    focal.vm.provision "shell",
      inline: "sed -i 's/MaxAuthTries.*/MaxAuthTries 10/g' /etc/ssh/sshd_config && systemctl restart sshd",
      upload_path: "/var/tmp/vagrant-shell"
  end
end
