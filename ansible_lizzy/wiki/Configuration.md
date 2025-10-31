# Configuration

## Inventory

Edit `homelab/inventories/production/hosts.yml` to define your hosts and groups. Example (excerpt):

```yaml
all:
  children:
    hosting:
      children:
        proxmox:
          hosts:
            pve01.example.net:
        core:
          children:
            dhcp:
              hosts:
                dhcp01.example.net:
            dns:
              hosts:
                dns01.example.net:
```

Use group hierarchy to scope variables and target plays.

## Variables

Set variables in `group_vars/` or `host_vars/` (create these folders alongside the inventory), or define inline vars when invoking playbooks.

Common toggles used in playbooks:
- `docker_enabled: true|false`
- `fail2ban_enabled: true|false`
- `lynis_enabled: true|false`
- `apparmor_enabled: true|false`
- `new_user: <username>` (for bootstrap and SSH validation)

Per-role variables live under each role’s `defaults/` and `vars/` directories. For Docker:
- `roles/docker/vars/<Distro>.yml` — package lists & repo setup per OS family
- `docker_daemon_options` — dict rendered into `/etc/docker/daemon.json`

## Credentials & Access

- Use SSH keys. The `make ssh-key` target helps copy your key to targets.
- Restrict Ansible control to a management network where possible.
- Consider storing secrets securely (Ansible Vault, external secret managers).
