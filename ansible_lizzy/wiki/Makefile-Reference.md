# Makefile Reference

The Makefile is the **preferred interface** for running this project. It wraps common flows and ensures the right flags are used.

> Exact targets may vary; run `make help` to list them on your system.

## Core Targets

- `make help` — list available targets.
- `make setup` / `make requirements` — set up control-node prerequisites (Python, Ansible, collections/roles).
- `make install-python` — ensure Python tooling exists on the control node.
- `make install-ansible` — install Ansible on the control node (via pip or distro tools).
- `make lint` — run `ansible-lint` over playbooks/roles.
- `make ssh-key` — copy your SSH public key to remote hosts (bootstrap access).
- `make first-apply` — run the **main playbook** as **root** (`ansible_user=root`), used for the initial bootstrap.
- `make apply` / `make run` — run the main playbook with privilege escalation (sudo).

## Pattern Targets

- **Role Tags** (pattern rule): `make <tag>`  
  Example: `make docker` → `ansible-playbook playbooks/all.yml --ask-become-pass --tags docker`

- **Specific Playbooks** (pattern rule): `make <playbook>`  
  Example: `make security` → `ansible-playbook ./playbooks/security.yml --ask-become-pass`

## Main Playbook

By default, targets call: `playbooks/all.yml`, which imports:
`pre-checks.yml → essentials.yml → configs.yml → monitoring.yml → backups.yml → access.yml → services.yml → security.yml → post-checks.yml`

> You can comment out imports in `all.yml` to slim the run, or invoke specific playbooks directly via `make <name>`.
