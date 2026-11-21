# Note to Evaluator: I am facing issues with deployment due to Amazon Free tier account. Its not allowing me to deploy EC2 using Terraform plan and I am planning to upgrade to a paid plan. I have requested extension for this project and plan to complete it before 26h November.


# TravelMemory with Terraform and Ansible

This repository prepares the TravelMemory MERN application for a single AWS deployment, managed with Terraform and configured with Ansible. It also includes a local Docker Compose demo. No AWS resources are created by reading, validating, or preparing these files.

## Current AWS status and cost controls

The account details shared earlier showed $120 in credits and a $20 project spend limit. Separately, the configured AWS role’s policy simulation returned organization-level explicit denies for required VPC, EC2, and IAM actions. An IAM allow policy cannot override those denies. **Do not run Terraform plan or apply until the account owner has resolved the organization restriction and rechecked permissions.** No account setting is changed by this repository.

The project spend limit and the $1 budget alert serve different purposes: the budget sends an alert, while the project limit can pause eligible project usage. Neither should be treated as an exact out-of-pocket cap. Credits may not cover every charge, and taxes, usage outside the project, and cleanup delays can still matter. The planned infrastructure includes two `t3.micro` instances, two 12 GiB gp3 volumes, one NAT Gateway and its public IPv4 address, and a public IPv4 address for the web server. The NAT Gateway accrues charges while it exists. Review current prices and spend-limit behavior in the AWS console before any future deployment.

Terraform has a `deployment_confirmed` guard that defaults to `false`. It is a deliberate-use check, **not** a spending limit. Once deployment is authorized and all required AWS actions are allowed, the operator must review the plan, deploy for the shortest practical window, and destroy the stack immediately afterward. Then verify in the AWS console that the instances, NAT Gateway, Elastic IP, and volumes are gone.

## Local demo

The Compose file expects a checkout of [TravelMemory](https://github.com/UnpredictablePrashant/TravelMemory) at `/tmp/TravelMemory` in WSL by default. Docker Desktop must have WSL integration enabled.

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project"
docker compose -f local-demo/compose.yaml up --build -d
docker compose -f local-demo/compose.yaml ps
```

Open the frontend at [http://localhost:8080](http://localhost:8080); the API health endpoint is [http://localhost:3001/health](http://localhost:3001/health). Both ports bind to localhost. Stop the containers and remove their network with:

```bash
docker compose -f local-demo/compose.yaml down
```

To also delete the local MongoDB and upload data volumes:

```bash
docker compose -f local-demo/compose.yaml down --volumes
```

If the source checkout is elsewhere, export `TRAVELMEMORY_SOURCE` with its WSL path before running Compose. The frontend API URL is compiled into the frontend image, so rebuild after changing it.

## Terraform

The `terraform/` directory defines a VPC, public and private subnets, internet and NAT gateways, security groups, two EC2 instances, SSH key registration, and instance roles for Systems Manager. The database instance is private; Ansible reaches it through the web instance using SSH ProxyJump. The React browser client calls the API on port 3001, so that API port is publicly reachable in the current design; MongoDB is restricted to the web instance’s security group.

From WSL, initialize and validate the configuration without creating AWS infrastructure:

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/terraform"
terraform init
terraform fmt -check
terraform validate
```

`terraform.tfvars.example` is a template. If deployment is authorized later, copy it to the ignored `terraform.tfvars`, replace `admin_cidr` with your current public IPv4 address in `/32` form, and keep `deployment_confirmed = false` until the final review. Do not commit `terraform.tfvars`, Terraform state, or saved plans.

## Ansible preparation and deployment

Ansible installs MongoDB 8.0 on the private Amazon Linux 2023 host, enables authentication, creates an administrator and a least-privilege application user, installs the TravelMemory backend and frontend on the web host, builds the React app with its API URL, configures systemd and nginx, and checks the API and site health. MongoDB and the web services are kept on separate instances.

Install Ansible in WSL before deployment. Create the local encrypted secret file; it is ignored by Git:

```bash
sudo apt update
sudo apt install ansible

cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/ansible"
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
```

Edit `group_vars/all/vault.yml` and replace both placeholder passwords with different, randomly generated secrets of at least 24 characters. Then encrypt it:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

Keep the vault password outside the repository. Do not put it in shell history, source control, or an unencrypted file in the project. The sample vault file contains placeholders only.

When the AWS permission restriction is resolved and deployment is authorized, use this order. Terraform creates only the infrastructure; Ansible then installs and starts the application:

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/terraform"
terraform apply -var="deployment_confirmed=true"

cd ../ansible
./scripts/generate-inventory.sh
ansible all -m ping
ansible-playbook site.yml --ask-vault-pass
```

Open the web server’s HTTP address shown by the inventory generator, confirm the application and `/health` endpoint work, and capture screenshots. Then remove the billable stack right away:

```bash
cd ../terraform
terraform destroy -var="deployment_confirmed=true"
```

Wait for destroy to finish and verify in the AWS console that EC2 instances, the NAT Gateway, its Elastic IP, and EBS volumes are gone. Destroying AWS resources does not remove local Terraform state or the local SSH key; keep those protected.

To rerun Ansible after the infrastructure exists, generate the local SSH configuration and inventory from Terraform outputs, then configure the hosts:

```bash
./scripts/generate-inventory.sh
ansible all -m ping
ansible-playbook site.yml --ask-vault-pass
```

The script expects the SSH private key at `~/.ssh/travelmemory-terraform`, matching the public-key path in Terraform. It writes `inventory.ini` and `ssh_config` locally; both are ignored by Git. The database host is reached through the web instance. The generated inventory does not exist before Terraform creates those hosts.

## Repository layout

```text
.
├── README.md
├── local-demo/compose.yaml
├── ansible/
│   ├── group_vars/
│   ├── playbooks/
│   ├── scripts/
│   └── templates/
├── iam/
└── terraform/
```

Never commit AWS credentials, private SSH keys, Ansible vault files or passwords, `.env` files, Terraform state, local variable files, or saved plans.
