#!/usr/bin/env bash

sudo apt install software-properties-common -y
sudo apt-add-repository -y --update ppa:ansible/ansible
sudo apt install ansible -y

ansible-playbook local.yml
