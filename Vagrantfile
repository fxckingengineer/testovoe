nodes = [
  { hostname: 'psql',     ip: '192.168.56.10', memory: 1024, cpu: 1, boxname: 'ubuntu/jammy64' },
  { hostname: 'backend',  ip: '192.168.56.20', memory: 1024, cpu: 1, boxname: 'ubuntu/jammy64' },
  { hostname: 'balancer', ip: '192.168.56.30', memory: 1024, cpu: 1, boxname: 'ubuntu/jammy64' }
]


Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  nodes.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      nodeconfig.vm.box = node[:boxname]
      nodeconfig.vm.hostname = node[:hostname]

      nodeconfig.vm.network :private_network,
        ip: node[:ip]
        
      nodeconfig.vm.provider :virtualbox do |vb|
        vb.memory = node[:memory]
        vb.cpus  = node[:cpu]
      end

      nodeconfig.vm.provision "file", source: "ansible.pub", destination: "/tmp/ansible.pub"
      nodeconfig.vm.provision "shell", privileged: true, path: "newUser.sh"

      if node[:hostname] == 'backend'
        nodeconfig.vm.provision "shell", path: "install_docker.sh", privileged: true
      end

    end
  end
end
