# Operations

## Day-2 Ops

- **Re-run configuration:** `make apply`
- **Run a specific section:** `make docker` / `make security` / `make services`
- **Lint changes:** `make lint`

## Updates

- Keep Ansible & roles current (`make requirements` or pin versions).
- For Docker hosts, plan maintenance windows for kernel updates and daemon restarts.
- Track security advisories for Fail2Ban, Lynis, and your distro.

## Backups

- Define what to back up (configs, volumes) in `backups.yml` and role vars.
- Test restores regularly.

## Logs

- Centralize logs if possible; add a monitoring stack in `monitoring.yml`.
