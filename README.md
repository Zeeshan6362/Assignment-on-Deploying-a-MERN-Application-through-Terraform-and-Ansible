# TravelMemory with Terraform and Ansible

This repository is a learning project for the assignment “Deploying a MERN Application through Terraform and Ansible.” The AWS infrastructure configuration is prepared for study, and a Docker Compose setup is provided for running the application locally.

## Deployment plan and billing guardrails

**No AWS infrastructure has been created yet.** The AWS account is currently on the Free Plan, whose organization-level policy denied required EC2/networking operations. The project is being prepared for deployment after the account owner upgrades to the Paid Plan. An IAM allow policy or another IAM user cannot override an explicit organization deny. After upgrading, verify the active plan and CLI role permissions before planning; if the same explicit deny remains, stop and contact AWS Support rather than changing IAM policies blindly.

AWS says remaining Free Tier credits generally apply after a direct Paid Plan upgrade and that charges beyond the credit balance, or for ineligible usage, are billed at standard rates. Upgrading is irreversible and upgrades all projects in the account. It does not make this a capped or “free” account. See [AWS plan comparison](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html) and [upgrade considerations and steps](https://docs.aws.amazon.com/in_en/accounts/latest/reference/upgrade-account.html).

This architecture is intentionally small: two `t3.micro` instances, two 12 GiB gp3 root volumes, one NAT Gateway, one NAT public IPv4 address, and one web public IPv4 address. Using published `us-east-1` example rates, its baseline is roughly **$0.08 per provisioned hour** before data processing, data transfer, taxes, and extra time during creation or cleanup. NAT data processing is additional. Leaving this baseline up for a full day is roughly $1.90 before those extras. Rates can change; confirm them in the AWS Pricing Calculator before applying. References: [T3 pricing](https://aws.amazon.com/ec2/instance-types/t3/), [NAT Gateway and public IPv4 pricing](https://aws.amazon.com/vpc/pricing/), [gp3 pricing](https://aws.amazon.com/ebs/general-purpose/).

AWS credits apply only to eligible charges and expire. The existing $1 budget is an alert, not a hard stop. The Paid Plan has a separate project spend limit that pauses a project at its limit, but AWS currently sets its minimum at the greater of $20 or a conservative estimate; the limit is pre-tax and credits are not counted toward it. This is a useful backstop, not a way to promise a $5–10 maximum. Read [how spend limits work](https://docs.aws.amazon.com/accounts/latest/reference/create-spend-limit.html). If you are not comfortable with a $20 minimum project usage limit, plus possible taxes or costs outside this project, do not upgrade for this lab.

Terraform now has an explicit `deployment_confirmed` safety gate that defaults to false. It prevents a normal plan until the operator deliberately sets it true; it is **not** a billing cap. When the lab is complete, run `terraform destroy` immediately and verify in the console that the NAT Gateway, Elastic IP, instances, and volumes are gone. Cleanup stops future usage but cannot refund charges already accrued.

### Upgrade and verify before the deployment

The account owner must perform this in the AWS console; do not join another AWS Organization or create a Control Tower landing zone as a workaround. AWS documents the direct upgrade path as:

1. Sign in to [AWS Settings](https://settings.aws.amazon.com) using the account owner login.
2. Open **Billing** and choose **Upgrade**.
3. Choose **Get started**, review the Paid Plan terms and account-wide/irreversible consequences, then add or confirm the payment method and required tax details.
4. Choose **Upgrade account**. If offered, review the project spend limit controls. A spend limit may not be settable below $20.
5. Verify the plan shows **Paid** and check the remaining credits and expiration date. Set the project spend limit if its offered amount and behavior fit your acceptable exposure.
6. In WSL, verify the CLI session still identifies the intended AWS account and role. Reauthenticate if needed, then simulate the Terraform create actions for that role. Do not apply if any required action is denied or `OrganizationsAllowed` is false.

Once the Paid Plan and permissions are confirmed, make a saved plan for review (this command does not create the planned resources):

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/terraform"
aws sts get-caller-identity --profile travelmemory-tf
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::464859024665:role/AccountFullAccessRole \
  --action-names ec2:CreateVpc ec2:CreateSubnet ec2:CreateInternetGateway ec2:AttachInternetGateway ec2:ModifyVpcAttribute ec2:ModifySubnetAttribute ec2:CreateRouteTable ec2:CreateRoute ec2:AssociateRouteTable ec2:AllocateAddress ec2:CreateNatGateway ec2:CreateSecurityGroup ec2:AuthorizeSecurityGroupIngress ec2:AuthorizeSecurityGroupEgress ec2:RunInstances ec2:CreateKeyPair ec2:CreateTags iam:CreateRole iam:CreateInstanceProfile iam:UpdateAssumeRolePolicy iam:AttachRolePolicy iam:PassRole \
  --resource-arns '*' \
  --context-entries ContextKeyName=aws:RequestedRegion,ContextKeyValues=us-east-1,ContextKeyType=string \
  --profile travelmemory-tf \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision,OrganizationsAllowed:OrganizationsDecisionDetail.AllowedByOrganizations}'
terraform plan -var="deployment_confirmed=true" -out=travelmemory.tfplan
terraform show travelmemory.tfplan
```

The role ARN above is the role reported by the project’s existing CLI profile. If `get-caller-identity` reports a different role, replace the ARN with that role’s IAM ARN before simulating. The simulation and plan are read-only; neither creates the AWS resources.

Only after reviewing the plan, remaining credits, spend-limit setup, and expected window should the user apply it:

```bash
terraform apply travelmemory.tfplan
```

Keep the session short, capture screenshots, and then destroy:

```bash
terraform destroy -var="deployment_confirmed=true"
```

Wait for Terraform to finish, then confirm in the AWS console that the NAT Gateway and its public IPv4 address, both EC2 instances, and both EBS volumes have been removed. If creation or destroy fails partway, inspect the console and clean up any remaining project resources before ending the session.

## Local TravelMemory demo (WSL Ubuntu)

The upstream application is maintained at [UnpredictablePrashant/TravelMemory](https://github.com/UnpredictablePrashant/TravelMemory). The Compose file builds its backend and frontend from a local checkout. By default, it expects the checkout at `/tmp/TravelMemory`, which is where the project was cloned during setup.

Prerequisites: Docker Desktop with WSL integration enabled, and Docker Compose v2 available inside the WSL Ubuntu distribution. Confirm in WSL:

```bash
docker --version
docker compose version
ls /tmp/TravelMemory/backend/Dockerfile /tmp/TravelMemory/frontend/Dockerfile
```

Start the demo from the project directory:

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project"
docker compose -f local-demo/compose.yaml up --build -d
docker compose -f local-demo/compose.yaml ps
```

Open the frontend at [http://localhost:8080](http://localhost:8080). The API health endpoint is [http://localhost:3001/health](http://localhost:3001/health). MongoDB and uploaded images are stored in local Docker volumes. The ports are bound to localhost only.

To view activity and stop the containers:

```bash
docker compose -f local-demo/compose.yaml logs -f
# Press Ctrl+C to leave the log view, then:
docker compose -f local-demo/compose.yaml down
```

`down` stops and removes the containers and network but preserves local database and upload volumes. To remove those local demo data volumes too:

```bash
docker compose -f local-demo/compose.yaml down --volumes
```

If the source checkout is elsewhere, set `TRAVELMEMORY_SOURCE` to its absolute WSL path before running Compose, for example:

```bash
export TRAVELMEMORY_SOURCE="$HOME/TravelMemory"
```

The frontend backend URL is compiled into the frontend image, so rebuild after changing it. For a different local port or deployment topology, update the Compose build argument and backend CORS origin together.

## Terraform configuration

The `terraform/` directory contains a Terraform configuration for a VPC, public and private subnets, Internet Gateway, NAT Gateway, route tables, security groups, IAM instance roles, and web/database EC2 instances. It is prepared for a short Paid Plan lab, pending post-upgrade permission checks.

Terraform formatting and static configuration validation do not create cloud resources. From WSL, after Terraform is installed:

```bash
cd "/mnt/c/Users/zeesh/Downloads/Terraform and Anisble project/terraform"
terraform fmt -check
terraform validate
```

`terraform init` downloads provider plugins and writes local metadata; it makes no AWS resources. The example variables file contains a documentation-only IP placeholder; `terraform.tfvars` is local and ignored by Git. Do not set `deployment_confirmed=true` until you have reviewed the costs and paid-plan controls.

## Ansible and remaining assignment work

The assignment's Ansible phase configures EC2 hosts and deploys the app. It cannot be exercised until the AWS hosts are created; this repository does not yet claim that the Ansible deployment phase is complete. The local Compose demo provides a way to show the full MERN application before the paid lab.

## Repository layout

```text
.
├── README.md
├── local-demo/
│   └── compose.yaml
├── ansible/
│   └── README.md
├── iam/
│   ├── travelmemory-network-terraform-policy.json
│   └── travelmemory-compute-terraform-policy.json
└── terraform/
│   ├── compute.tf
│   ├── main.tf
│   ├── network.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
```

Never commit AWS credentials, private SSH keys, Terraform state, local variable files, `.env` files, or Ansible vault passwords. Review `git status` before each commit.
