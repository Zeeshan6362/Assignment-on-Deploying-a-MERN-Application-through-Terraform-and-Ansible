# Ansible deployment

`site.yml` runs the database setup first, then deploys the TravelMemory API and built React frontend to the web host. The inventory and SSH configuration are generated from Terraform outputs only after the infrastructure exists.

Before any cloud deployment is authorized, prepare the local encrypted secret file:

```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# Edit both placeholder passwords, then encrypt the file:
ansible-vault encrypt group_vars/all/vault.yml
```

Use unique random secrets of at least 24 characters. Keep the vault password somewhere outside this repository. `vault.yml`, `inventory.ini`, and `ssh_config` are excluded by `.gitignore`.

After Terraform has created the EC2 hosts, run from this directory:

```bash
./scripts/generate-inventory.sh
ansible all -m ping
ansible-playbook site.yml --ask-vault-pass
```

The generator reads `web_public_ip`, `web_public_dns`, and `database_private_ip` from Terraform outputs. It expects `~/.ssh/travelmemory-terraform`. The database is accessed through the web server with SSH ProxyJump. No AWS dynamic inventory plugin or extra Python AWS SDK is needed.

The playbooks install MongoDB 8.0 on Amazon Linux 2023, configure authenticated database access, and create an application user with only `readWrite` access to the TravelMemory database. On the web host they install Node.js 22 and nginx, build the upstream frontend against the web host API endpoint, configure the API as a systemd service, and check both the API health route and nginx response.

The playbooks cannot be run against real hosts until Terraform creates them and the AWS role is allowed to create the required resources. Do not commit credentials, vault files or passwords, generated inventory, SSH configuration, or private keys.
