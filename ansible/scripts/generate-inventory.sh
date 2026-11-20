#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "${script_dir}/../.." && pwd)"
terraform_dir="${project_root}/terraform"
ssh_key="${HOME}/.ssh/travelmemory-terraform"

if [[ ! -r "${ssh_key}" ]]; then
  printf 'SSH private key not found: %s\n' "${ssh_key}" >&2
  exit 1
fi

web_ip="$(terraform -chdir="${terraform_dir}" output -raw web_public_ip)"
web_dns="$(terraform -chdir="${terraform_dir}" output -raw web_public_dns)"
database_ip="$(terraform -chdir="${terraform_dir}" output -raw database_private_ip)"

umask 077
cat > "${script_dir}/inventory.ini" <<EOF
[web]
travelmemory-web ansible_host=travelmemory-web travelmemory_public_dns=${web_dns}

[database]
travelmemory-database ansible_host=travelmemory-database database_private_ip=${database_ip}

[all:vars]
ansible_user=ec2-user
ansible_python_interpreter=/usr/bin/python3
EOF

cat > "${script_dir}/ssh_config" <<EOF
Host travelmemory-web
    HostName ${web_ip}
    User ec2-user
    IdentityFile ${ssh_key}
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new

Host travelmemory-database
    HostName ${database_ip}
    User ec2-user
    IdentityFile ${ssh_key}
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ProxyJump travelmemory-web
EOF

chmod 600 "${script_dir}/inventory.ini" "${script_dir}/ssh_config"
printf 'Created local Ansible inventory and SSH config.\n'
printf 'Web address: http://%s\n' "${web_dns}"
printf 'Database private address: %s (reachable through the web host)\n' "${database_ip}"
