# Note to Evaluator: I am facing issues with deployment due to Amazon Free tier account. Its not allowing me to deploy EC2 using Terraform plan and I am planning to upgrade to a paid plan. I have requested extension for this project and plan to complete it before 26h November.


# TravelMemory with Terraform and Ansible

This repository deploys the TravelMemory MERN application to AWS with Terraform and configures it with Ansible. It also includes a Docker Compose demo for local learning. The AWS deployment described here was completed as a temporary learning exercise and has since been destroyed.

## AWS account access: challenge and resolution

The first AWS account context used for the project was governed by an AWS Organizations service control policy (SCP). Policy simulation showed explicit denies for the VPC, EC2, and IAM actions required by this assignment. An IAM allow policy could not override those organization-level denies, so Terraform could not deploy the stack in that context.

After Advanced features were activated in AWS account settings, AWS provided access to the organization management account. We switched the AWS CLI to a profile for that account, confirmed the active identity with `aws sts get-caller-identity`, and used that account for the deployment. Terraform then created the infrastructure and Ansible deployed the application. This records the observed account setup for this project; it does not imply that activating Advanced features removes every organization policy or grants permissions in every AWS account.

AWS credits and budgets are not guaranteed hard spending caps. A budget alert notifies the account owner; it does not automatically stop every resource. NAT Gateways, public IPv4 addresses, EC2 instances, and storage can incur charges while they exist, and accrued usage may remain on the bill after teardown. Review the current account terms and estimated charges before deployment, keep the live window short, and verify deletion in the AWS console afterward.

## What the project builds

Terraform provisions a VPC with public and private subnets, an Internet Gateway, a NAT Gateway, routing, security groups, two EC2 instances, an SSH key pair, and EC2 instance roles. The web host is public; the MongoDB host is private and is reached by Ansible through the web host using SSH ProxyJump. MongoDB is reachable only from the web security group. The current application design exposes its API on port 3001 so browsers can reach it.

Ansible installs and configures MongoDB 8.0 with authentication, creates an administrator and a least-privilege application user, installs the TravelMemory backend and frontend, builds the React frontend with the API URL, and configures the API service and nginx. It also checks the API health route and the served frontend.

## Deployment outcome

The temporary AWS deployment completed successfully. The browser displayed the TravelMemory app, a sample trip was saved and viewed, and the API health check returned `status: ok` with the database connected. Terraform then reported **21 resources destroyed**, including the EC2 instances and NAT Gateway. The account owner confirmed the AWS resources had stopped. The deployment is therefore not live now; recreating it requires a new Terraform apply followed by Ansible.

## AWS account issues and deployment fixes

The deployment exposed several practical issues that are documented and corrected in the project files:

- The initial account role was explicitly denied required infrastructure actions by an organization SCP. The project was deployed using the management-account profile made available after Advanced features activation.
- Ansible ignored `ansible.cfg` when run from the world-writable Windows-mounted WSL directory. Set `ANSIBLE_CONFIG` explicitly from the `ansible/` directory before running Ansible.
- The inventory generator originally wrote `inventory.ini` and `ssh_config` under `ansible/scripts/`, while Ansible expected them under `ansible/`. The script now writes them beside `ansible.cfg`.
- The playbooks now load shared settings and the encrypted vault file explicitly with `vars_files`.
- MongoDB 8 rejected the obsolete `storage.journal.enabled` configuration option. Journaling is enabled by default, so that option was removed.
- The web play now creates `/etc/travelmemory` before writing the backend environment file.
- A new WSL terminal did not have the SSH key loaded in its SSH agent. Start an agent and add the project key before connecting if prompted for SSH authentication.
- The frontend’s API and CORS configuration use the EC2 DNS hostname. Open the frontend using that hostname rather than its raw IP address so the browser origin matches the configured API origin.

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

Terraform files are in `terraform/`. Initialize and validate without creating AWS infrastructure:

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/terraform"
terraform init
terraform fmt -check
terraform validate
```

For an AWS deployment, configure CLI credentials for the intended account and select `us-east-1`. Confirm the identity before using Terraform:

```bash
export AWS_PROFILE=travelmemory-tf
export AWS_REGION=us-east-1
aws sts get-caller-identity
```

`terraform.tfvars.example` is a template. Copy it to the ignored `terraform.tfvars` and replace `admin_cidr` with the administrator’s current public IPv4 address in `/32` form. Keep `deployment_confirmed` false until reviewing the account, plan, cost exposure, and teardown steps. This variable is a deliberate-use guard, not a spending limit. The apply command requires the explicit confirmation variable:

```bash
terraform plan -var="deployment_confirmed=true" -out=travelmemory.tfplan
terraform show travelmemory.tfplan
terraform apply travelmemory.tfplan
```

Do not commit `terraform.tfvars`, Terraform state, or saved plans.

## Ansible setup and deployment

Install Ansible in WSL and create the local encrypted secret file. The vault file is ignored by Git:

```bash
sudo apt update
sudo apt install ansible

cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/ansible"
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
```

Edit `group_vars/all/vault.yml`, replacing both placeholders with different, randomly generated secrets of at least 24 characters, then encrypt it:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

Keep the vault password outside the repository. Do not put it in shell history, source control, or an unencrypted project file.

After Terraform apply succeeds, generate the local inventory and SSH configuration, test access, and run the playbooks:

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/ansible"
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
./scripts/generate-inventory.sh
ansible all -m ping --ask-vault-pass
ansible-playbook site.yml --ask-vault-pass
```

Enter the vault password when prompted. The generator reads Terraform outputs and writes `inventory.ini` and `ssh_config` into `ansible/`; both are ignored by Git. The private database host is reached through the web host. The SSH private key must be at `~/.ssh/travelmemory-terraform`, matching the public-key path in Terraform. If the key is passphrase-protected and not loaded in the current WSL session, start `ssh-agent` and add the key with `ssh-add`.

When the playbook succeeds, open the web address printed by the inventory generator using its DNS hostname. Verify the app and API, capture any required evidence, then destroy the stack immediately:

```bash
cd ../terraform
terraform destroy -var="deployment_confirmed=true"
```

Wait for destroy to finish. Verify in the AWS console that EC2 instances, the NAT Gateway, its Elastic IP, and EBS volumes are gone. Destroying AWS resources does not remove local Terraform state or the local SSH key; keep those protected.

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
