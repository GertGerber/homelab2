# homelab2

ADDING VARIABLES 🗂️
--------------------
- Secrets should be stored in a vault: ./inventories/group_vars/vault.yml
  1. Create a vault: `ansible-vault create ~/.config/vault.yml`
  2. Vault password set in ~/.config/.vault_pass.txt
  3. Edit the vault: `ansible-vault edit ~/.config/vault.yml`
  4. Use the vault by adding the `--ask-vault-pass` flag when running a playbook
