#!/usr/bin/env bash

sudo apt install software-properties-common -y --update
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt install ansible -y

ansible-playbook local.yml
