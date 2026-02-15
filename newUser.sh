#!/usr/bin/env bash

useradd -m -s /bin/bash ansible

mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh

cat /tmp/ansible.pub > /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys

chown -R ansible:ansible /home/ansible/.ssh

echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible