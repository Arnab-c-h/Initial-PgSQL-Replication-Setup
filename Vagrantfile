# Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64" # Ubuntu 20.04 LTS

  # Disable default synced folder to avoid permissions issues with Docker inside VM
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # --- Master Node ---
  config.vm.define "master" do |master|
    master.vm.hostname = "pgsql-master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.provision "docker" 

    # Sync master-specific Docker configuration
    master.vm.synced_folder "./pg_config_master", "/home/vagrant/pg_config_master"

    # Port forward PostgreSQL for access from host
    master.vm.network "forwarded_port", guest: 5432, host: 15432

    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

  # --- Slave1 Node ---
  config.vm.define "slave1" do |slave1|
    slave1.vm.hostname = "pgsql-slave1"
    slave1.vm.network "private_network", ip: "192.168.56.11"
    slave1.vm.provision "docker" 

    # Sync slave1-specific Docker configuration
    slave1.vm.synced_folder "./pg_config_slave1", "/home/vagrant/pg_config_slave1"

    # Port forward PostgreSQL for access from host
    slave1.vm.network "forwarded_port", guest: 5432, host: 15433

    slave1.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

  # --- Slave2 Node ---
  config.vm.define "slave2" do |slave2|
    slave2.vm.hostname = "pgsql-slave2"
    slave2.vm.network "private_network", ip: "192.168.56.12"
    slave2.vm.provision "docker" 

    # Sync slave2-specific Docker configuration
    slave2.vm.synced_folder "./pg_config_slave2", "/home/vagrant/pg_config_slave2"

    # Port forward PostgreSQL for access from host
    slave2.vm.network "forwarded_port", guest: 5432, host: 15434

    slave2.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end
end