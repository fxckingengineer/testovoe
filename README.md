
# Содержание

## Используемый софт

- Vagrant (на Windows машине)
- VirtualBox (на Windows машине)
- Ansible (в WSL)
- Docker (в ВМ, которая будет создана в будущем)

## Все файлы для работы

Для Vagrant нужны:
- vagrantfile (Основной файл конфигурации ВМ)
- ansible.pub (Публичный ssh ключ)
- newUser.sh (Для создания пользователя)
- install_docker.sh (Для установки Docker на нужную машину)

Для Ansible нужны:
- ansible.cfg (Настройки для ansible)
- inventory/hosts.ini (Здесь хранятся ип хостов)
- multiple_playbook.yml (Основной плейбук)
- playbooks/* (Остальные плейбуки)
	- install_psql.yml (Установка psql)
	- psql.yml (Создание БД)
	- docker.yml (Копирование и запуск docker-compose.yml)
	- install_nginx.yml (Установка и настройка nginx)
- repository/docker-compose.yml (Сам compose который мы запускаем)
- repository/balancer (конфиг nginx)
# Начало работы. Установка нужного софта

Установка `Vagrant` с офф сайта https://developer.hashicorp.com/vagrant/install
Установка VirtualBox с офф сайта https://www.virtualbox.org/wiki/Downloads
Установка `Ansible` с офф сайта https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html

>[!INFO] Перед установкой ansible, следует установить python, venv и pip. Дальше создать виртуальное окружение и устанавливать сам Ansible через pip
>

# Шаг 1. Запуск ВМ

>[!INFO] Vagrant установлен/запускается на Windows хосте

> Для начала работы нужно сгенерировать ssh-key и публичный ключ переименовать в ansible.pub(Можно не переименовывать, а своё название поменять в скрипте newUser.sh)

> Private ключ нужно будет скопировать на хост ansible.

> [!INFO] Все файлы для `vagrant` должны лежать в одной директории

Запуск ВМ:

```PowerShell
vagrant up
```

Данная команда запускает 3 ВМ с именами:
- psql (Сервер БД)
- backend (Сервер на котором будет находится docker и 3 контейнера)
- balancer (Сервер nginx, который выполняет роль балансировщика)

Сам `vagrantfile` выглядит так:

```Ruby
nodes = [
  { hostname: 'psql',     ip: '192.168.0.130', memory: 1024, cpu: 1, boxname: 'ubuntu/jammy64' },
  { hostname: 'backend',  ip: '192.168.0.131', memory: 1024, cpu: 1, boxname: 'ubuntu/jammy64' },
  { hostname: 'balancer', ip: '192.168.0.132', memory: 1024, cpu: 1, boxname: 'ubuntu/jammy64' }
]

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false 
  nodes.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      nodeconfig.vm.box = node[:boxname]
      nodeconfig.vm.hostname = node[:hostname]
      
      nodeconfig.vm.network :public_network,
        ip: node[:ip],
        bridge: "Hyper-V Virtual Ethernet Adapter #2"
        
      nodeconfig.vm.provider :virtualbox do |vb|
        vb.memory = node[:memory]
        vb.cpus  = node[:cpu]
      end
      
      nodeconfig.vm.provision "file", source: "ansible.pub", destination: "/tmp/ansible.pub"
      nodeconfig.vm.provision "shell", privileged: true, path: "newUser.sh"
      
      if node[:hostname] == 'backend'
        nodeconfig.vm.provision "shell", path: "install_docker.sh", privileged: true
      end
    end
  end
end
```

Создаются 3 ВМ с публичными ip (Нужно использовать подсеть вашего роутера, если делаете по той же схеме как я), у этих 3-ех ВМ 1Гб ОЗУ и 1 CPU, бокс с ОС берётся с офф. сайта: https://portal.cloud.hashicorp.com/vagrant/discover?providers=virtualbox&query=ubuntu%2Fjammy

В качестве ОС выбрана Ubuntu/jammy.

В строке:
```Ruby
nodeconfig.vm.network :public_network,
  ip: node[:ip],
  bridge: "Hyper-V Virtual Ethernet Adapter #2"      
```

Нужно заменить строку bridge, если конфигурация Win+WSL.

Скрипт **newUser.sh** создает пользователя с именем ansible, он нам нужен для запуска playbook's.

```Bash
#!/usr/bin/env bash

useradd -m -s /bin/bash ansible

mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh

cat /tmp/ansible.pub > /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys

chown -R ansible:ansible /home/ansible/.ssh

echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible
```

Скрипт **install_docker.sh** устанавливает docker на ВМ с именем хоста backend

```Bash
# Add Docker's official GPG key:

sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```


# Шаг 2. Запуск playbook

>[!INFO] ansible находится в WSL, так как офф его нет на windows

inventory/hosts.ini

```YAML
[test]

psql ansible_host=192.168.0.130 ansible_user=ansible ansible_ssh_private_key_file=/home/ansible/.ssh/ansible
backend ansible_host=192.168.0.131 ansible_user=ansible ansible_ssh_private_key_file=/home/ansible/.ssh/ansible
balancer ansible_host=192.168.0.132 ansible_user=ansible ansible_ssh_private_key_file=/home/ansible/.ssh/ansible
```

В данном файле содержится информация о хостах, под каким пользователем они подключаются и откуда брать приватный ключ при подключении.

ansible.cfg

```YAML
[defaults]
host_key_checking = False
allow_world_readable_tmpfiles = True
```

`host_key_checking = False` - отключает проверку файла known_hosts
`allow_world_readable_tmpfiles = True` Позволяет создавать временные файлы для пользователя (Нужен для корректной работы playbook psql.yml)


Запуск родительского playbook: 

```Bash
ansible-playbook -i inventory/hosts.ini multiple_playbook.yml
```

Сам playbook:

```YAML
---

- hosts: all
  gather_facts: false
  tasks:
    - name: Wait for SSH
      ansible.builtin.wait_for_connection:
        timeout: 30

- import_playbook: ./playbooks/install_psql.yml
- import_playbook: ./playbooks/psql.yml
- import_playbook: ./playbooks/docker.yml
- import_playbook: ./playbooks/install_nginx.yml

```

Timeout нужен для того, чтобы подключение точно произошло и плейбук не завершился с ошибкой.

Данный плейбук запускает 4 других.

## install_psql.yml: 

```YAML
---

- name: Install python and psql
  hosts: psql
  gather_facts: false
  become: true
  tasks:
  - name: Install pkg
    ansible.builtin.apt:
      update_cache: true
      pkg:
      - python3
      - python3-pip
      - python3-venv
      - python3-dev
      - build-essential
      - libxml2-dev
      - libxslt1-dev
      - libffi-dev
      - libpq-dev
      - libssl-dev
      - zlib1g-dev
      - curl
      - ca-certificates
      - gnupg2
      - python3-psycopg2
  - name: Install Postgresql-common
    ansible.builtin.apt:
      update_cache: true
      name: postgresql-common
  - name: Add Repository PSQL
    ansible.builtin.shell:
      cmd: printf "\n" | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
  - name: Install PSQL
    ansible.builtin.apt:
      update_cache: true
      name: postgresql
  - name: Replace a listen_addresses in postgresql.conf
    ansible.builtin.lineinfile:
      path: /etc/postgresql/18/main/postgresql.conf
      search_string: 'listen_addresses'
      line: listen_addresses = '*'
      owner: root
      group: root
      mode: '0644'
  - name: Change pg_hba.conf
    ansible.builtin.lineinfile:
      path: /etc/postgresql/18/main/pg_hba.conf
      line: host    all             all             192.168.0.0/24          scram-sha-256
  - name: Restart service postgresql
    ansible.builtin.service:
      name: postgresql
      state: restarted

```

Данный playbook устанавливает python и дополнительные пакеты, так же устанавливает PSQL и редактирует файлы postgresql.conf и pg_hba.conf для того чтобы backend мог подключится к удаленной БД.

## psql.yml

```YAML
---

- name: Create DB
  hosts: psql
  become: true
  become_user: postgres
  gather_facts: false
  tasks:
  - name: Create new Database
    community.postgresql.postgresql_db:
      name: testdb
  - name: Create new user in PSQL
    community.postgresql.postgresql_user:
      login_db: testdb
      name: testuser
      password: password
  - name: Set owner as testuser in db testdb
    community.postgresql.postgresql_owner:
      login_db: testdb
      new_owner: testuser
      obj_name: testdb
      obj_type: database
  - name: GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser
    community.postgresql.postgresql_privs:
      login_db: testdb
      privs: ALL
      type: database
      obj: testdb
      role: testuser
```

Данный playbook создаёт тестовую БД с именем testdb и пользователя с именем testuser на хосте psql

## docker.yml

```YAML
---

- name: Start docker compose
  hosts: backend
  gather_facts: false
  become: true
  tasks:
  - name: Create project dir
    ansible.builtin.file:
      path: /opt/backend
      state: directory
      mode: '0755'
  - name: Copy docker-compose.yml
    ansible.builtin.copy:
      src: /opt/testovoe/repository/docker-compose.yml
      dest: /opt/backend/docker-compose.yml
      owner: root
      group: root
      mode: '0644'
  - name: Run docker compose
    community.docker.docker_compose_v2:
      project_src: /opt/backend
  - name: Restart docker compose
    community.docker.docker_compose_v2:
      project_src: /opt/backend
      state: restarted
```

Данный playbook создаёт директорию, копирует с хоста ansible, на хост backend файл docker-compose.yml и запускает его

*P.S. По какой-то причине после запуска 3 контейнеров, 1-2 контейнера могут не запуститься, поэтому тут присутствует task перезапускающий контейнеры.*

В данном playbook запускается docker compose
### docker-compose.yml

```YAML
---

services:
  web-1:
    image: m1sse/fastapi-backend
    ports:
      - 8000:8000
    environment:
      - DB_HOST=192.168.0.130
      - DB_USER=testuser
      - DB_PASSWORD=password
      - DB_NAME=testdb
  web-2:
    image: m1sse/fastapi-backend
    ports:
      - 8001:8000
    environment:
      - DB_HOST=192.168.0.130
      - DB_USER=testuser
      - DB_PASSWORD=password
      - DB_NAME=testdb
  web-3:
    image: m1sse/fastapi-backend
    ports:
      - 8002:8000
    environment:
      - DB_HOST=192.168.0.130
      - DB_USER=testuser
      - DB_PASSWORD=password
      - DB_NAME=testdb
```

Три одинаковых контейнера, которые подключаются к одной БД и меняется только внешний порт.


## install_nginx.yml

```YAML
---
- name: Install nginx
  hosts: balancer
  gather_facts: false
  become: true
  tasks:
    - name: Install nginx package
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
    - name: Remove default file nginx
      ansible.builtin.file:
        path: /etc/nginx/sites-enabled
        state: absent
    - name: Copy new config file nginx
      ansible.builtin.copy:
        src: /opt/testovoe/repository/balancer
        dest: /etc/nginx/sites-enabled/
        mode: '0644'
        owner: www-data
        group: www-data
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

Данный playbook устанавливает nginx, копирует новый конфиг сайта с именем balancer и удаляет стандартный с именем default.


# Шаг 3. Проверка работоспособности

На хосте с которого можно подключится к хосту balancer или на самом balancer выполняем команду: 

```bash
curl -I 192.168.0.132/health
```

Получаем вывод: 

```
root@balancer:~# curl -I http://192.168.0.132/health
HTTP/1.1 405 Method Not Allowed
Server: nginx/1.18.0 (Ubuntu)
Date: Sun, 15 Feb 2026 07:45:40 GMT
Content-Type: application/json
Content-Length: 31
Connection: keep-alive
allow: GET
X-Upstream: 192.168.0.131:8000
```

**X-Upstream: 192.168.0.131:8000** - Показывает к какому именно контейнеру было обращение.
У нас подняты 3 контейнера с 3 портами:
- 8000
- 8001
- 8002

# P.S. Масштабирование.

В данной конфигурации можно поменять **docker-compose.yml** и добавить 4 контейнер, изменив только имя и внешний порт.

Так же в конфиге для nginx **balancer** нужно добавить ip-address с портом в блок **upstream python_backend**