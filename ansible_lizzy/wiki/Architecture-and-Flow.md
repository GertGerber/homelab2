# Architecture & Flow

The homelab is delivered in layered stages using Ansible. The diagram below reflects the sequence in `playbooks/all.yml`.

```mermaid
flowchart TD
  A[Start] --> B[Control node ready (Python, Ansible)]
  B --> C[Inventory configured: homelab/inventories/production/hosts.yml]
  C --> D[Pre-checks: facts, variables, SSH verification]
  D --> E[Essentials: users, SSH, directories, timezone, host, firewall]
  E --> F[Configs: shell/dotfiles]
  F --> G[Monitoring: observability scaffolding]
  G --> H[Backups: schedules & policies]
  H --> I[Access: cockpit/vpn as enabled]
  I --> J[Services: install Docker Engine + Compose v2]
  J --> K[Security: Fail2Ban, Lynis, AppArmor]
  K --> L[Post-checks: assertions & smoke tests]
  L --> M[Operate: updates, backup, logs]
```
