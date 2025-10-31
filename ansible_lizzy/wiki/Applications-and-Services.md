# Applications & Services

This page explains **what is installed** and **where it is configured**, based on the playbooks and roles in the repo.

---

## Playbook: `playbooks/all.yml` (Main Entrypoint)

A full run imports the following (in sequence). Toggle or customize by editing `homelab/playbooks/all.yml` or running specific playbooks via Makefile patterns (see **Makefile Reference**).

1. **Pre-checks** — `pre-checks.yml`
   - Gathers facts, prints system summary, asserts prerequisites and variables.
   - Verifies SSH access for the configured user.
   - _Where to configure:_ inventory variables and any required `new_user`/SSH details.

2. **Essentials** — `essentials.yml`
   - Baseline server setup (_users, SSH, directories, timezone, hostname, firewall, mail_).
   - _Where to configure:_ create/enable roles like `users`, `ssh`, `timezone`, etc., or adapt tasks in this playbook.

3. **Configs** — `configs.yml`
   - Shell and dotfiles customization for users.
   - _Where to configure:_ vars in inventory/group_vars; extend with your own role for dotfiles if desired.

4. **Monitoring** — `monitoring.yml`
   - Observability placeholders. Add Prometheus/Loki/Node Exporter as needed.
   - _Where to configure:_ define your monitoring stack here.

5. **Backups** — `backups.yml`
   - Scheduled backup orchestration.
   - _Where to configure:_ target paths, policies, and schedules in vars.

6. **Access** — `access.yml`
   - Installs and configures administrative access tools (e.g., Cockpit, VPN).
   - _Where to configure:_ enable/disable per tool with `*_enabled` vars.

7. **Services** — `services.yml`
   - **Installs Docker** on targets and prepares the host for container workloads.
   - _Where to configure:_ `docker_enabled: true|false`; role variables under `homelab/roles/docker/` and vendored `geerlingguy.docker`.

8. **Security** — `security.yml`
   - Hardening and security controls. Includes tasks/roles for:
     - **Fail2Ban** — intrusion prevention
     - **Lynis** — security auditing
     - **AppArmor** — process confinement (enforced if supported)
   - _Where to configure:_ set `fail2ban_enabled`, `lynis_enabled`, `apparmor_enabled` booleans and related vars.

9. **Post-checks** — `post-checks.yml`
   - Final validations and service smoke-tests.

> 💡 Each sub-playbook is intentionally modular. You can comment out imports you don’t need, or run just a subset via Make targets.

---

## Role: `roles/docker` (Custom)

Installs and configures **Docker Engine** and **Compose v2** across supported distros.

- **What it does**
  - Removes obsolete Docker packages for the target distro.
  - Installs Docker CE repo & engine packages.
  - Installs the Compose v2 plugin.
  - Ensures `/etc/docker/` exists and can apply daemon options.
- **Key files**
  - `roles/docker/tasks/main.yml` — distro dispatch and install sequence.
  - `roles/docker/vars/<Distro>.yml` — distro-specific package lists & settings.
- **Variables**
  - `docker_enabled` (bool): gate the role in `services.yml`.
  - `docker_daemon_options` (dict): JSON-serializable options for `/etc/docker/daemon.json`.
- **Tags**: `docker`

> There are also vendored upstream roles under `homelab/.ansible/roles/` and `homelab/roles/geerlingguy.*` that provide a similar capability. Prefer your custom role or pin a specific upstream version.

---

## Security Stack (from `security.yml`)

- **Fail2Ban** (`fail2ban_enabled: true`)  
  Blocks repeat offenders by banning IPs with suspicious authentication patterns.
- **Lynis** (`lynis_enabled: true`)  
  Audits system hardening and recommends remediations.
- **AppArmor** (`apparmor_enabled: true`)  
  Enforces profiles; the playbook also asserts that AppArmor is **enabled** after a run.

---

## “Essentials” Baseline

While the example playbook is a template, it is designed to provide:
- Package installs & updates, user management, directory structure
- SSH hardening, timezone/NTP, hostname & `/etc/hosts`
- Firewall and basic mail config

Enable or extend the roles listed as comments in `essentials.yml`, or replace with your own.

---

## Add Your Application Stacks

Once Docker is present, add folders like `stacks/<app>/docker-compose.yml` or Ansible roles for each app, then include them in a dedicated playbook (e.g., `apps.yml`) and run via:

```bash
make apps    # if defined as a playbook/target
```

Document each app’s ports, volumes, and credentials in a per-app README.
