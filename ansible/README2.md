How to target

Control plane only: ansible all -i homelab/ansible/inventories/production/hosts.yml -l control_plane -m ping

Proxmox node(s): ansible-playbook -i homelab/ansible/inventories/production/hosts.yml pve.yml -l proxmox

Network stack: ansible-playbook -i homelab/ansible/inventories/production/hosts.yml network.yml -l network

DNS only: -l dns

Ad-blocking tier only: -l adblock