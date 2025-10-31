# Troubleshooting

## Connectivity / SSH
- Verify inventory hostnames/IPs resolve and are reachable.
- Run: `ansible -i homelab/inventories/production/hosts.yml all -m ping`

## Privilege escalation
- If `sudo` is required, targets should be run with `--ask-become-pass` (the Makefile already adds this for you).

## Docker install issues
- Confirm OS family vars loaded: see `roles/docker/vars/`.
- Check daemon creation & options at `/etc/docker/daemon.json`.

## Security assertions fail
- AppArmor must be supported & enabled by the kernel; see distro docs.
- Review Lynis report and address findings iteratively.

## General
- Increase verbosity: append `-vvv` to the underlying `ansible-playbook` command.
- Validate YAML and structure with `make lint`.
