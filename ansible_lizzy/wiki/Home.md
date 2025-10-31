# Homelab Wiki

Welcome! This wiki documents a production-ready, **Ansible-first** homelab. It explains what gets installed, how to run it using the **Makefile** workflow, how to configure it, and how everything fits together.

> **At a glance**
> - **Provisioning:** Ansible playbooks with roles for Docker, hardening, access, and more.
> - **Targets:** Run the whole stack or individual parts via `make`.
> - **Apps/Services installed:** Docker Engine + Compose plugin, security stack (Fail2Ban, Lynis, AppArmor), plus baseline system config.
> - **Extensible:** Add your own roles and app stacks once Docker is present.

---

## Quick Start (Makefile-driven)

> The Makefile orchestrates _everything_ (env setup, Ansible installs, initial run). You **do not** need Docker pre-installed on targets — the roles will install it.

```bash
# 0) Install dependencies on your control node if needed
make install-python install-ansible  # or 'make setup' / 'make requirements'

# 1) Set your inventory
$EDITOR homelab/inventories/production/hosts.yml

# 2) First-time full apply AS ROOT (bootstraps user, SSH, etc.)
make first-apply

# 3) Subsequent runs with privilege escalation (sudo)
make apply
```

Common helpers:
```bash
make ssh-key          # copy your SSH key to targets
make lint             # lint playbooks/roles
make help             # list all targets
```

---

## What Gets Installed

See **Applications & Services** for a detailed breakdown of each playbook and role, including variables, tags, and where to change settings.

- Core container stack: **Docker Engine** and **Docker Compose v2 plugin** (via `roles/docker` or vendored `geerlingguy.docker`).
- Security controls: **Fail2Ban**, **Lynis**, **AppArmor** (toggle via `*_enabled` vars).
- Baseline system configuration: users, SSH, directories, timezone, hostname, firewall, etc. (playbooks under `homelab/playbooks/`).

---

## Architecture & Flow

See **Architecture & Flow** page for the full Mermaid diagram.

---

## Where to Configure

- **Inventory:** `homelab/inventories/production/hosts.yml`
- **Global play selection:** `homelab/playbooks/all.yml` (imports sub-playbooks)
- **Per-role defaults/vars:** under `homelab/roles/<role>/` and vendored roles in `homelab/.ansible/roles/`
- **Feature toggles:** use boolean vars like `docker_enabled`, `lynis_enabled`, `apparmor_enabled` in your inventory/group_vars/host_vars.

---

_Last updated: 2025-10-31 05:32 UTC_
