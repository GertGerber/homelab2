---
- name: Proxmox | Create user, role, and API token (wrapper)
  hosts: hosting
  gather_facts: false
  become: true

  roles:
    - role: create_proxmox_user
