# Run book

1. Provision
```bash
cd terraform
terraform init
terraform apply -var-file=example.tfvars
```

2. Configure
```bash
cd ../ansible
# (Recommended) Put sensitive vars in vault before running
ansible-playbook -i inventory/hosts.ini site.yml
```

3. Validate
```bash
# From a client or DC:
realm="lab.home"
host dc1
kinit Administrator
samba-tool domain level show
host -t SRV _ldap._tcp.${realm}
```