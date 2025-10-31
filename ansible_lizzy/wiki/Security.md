# Security

- **Account hygiene:** unique admin users, SSH keys only, disable password auth where possible.
- **Network exposure:** limit management UIs to LAN/VPN.
- **Hardening:** leave `security.yml` enabled; AppArmor and Fail2Ban provide meaningful baselines.
- **Secrets:** use Ansible Vault; avoid committing secrets to VCS.
- **Auditing:** run Lynis regularly and track regressions.
