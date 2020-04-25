# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  config.vm.box = "debian/buster64"

  config.vm.network "forwarded_port", guest: 8083, host: 8083

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
    if ! dpkg -s fhem >/dev/null 2>&1; then
      apt-get install -y gnupg
      wget -qO - http://debian.fhem.de/archive.key | sudo apt-key add -
      echo "deb http://debian.fhem.de/nightly/ /" > /etc/apt/sources.list.d/fhem.list
      apt-get update
      apt-get install -y fhem
      ln -sf /vagrant/FHEM/59_LuftdatenInfo.pm /opt/fhem/FHEM/59_LuftdatenInfo.pm 
    fi
  SHELL
end
