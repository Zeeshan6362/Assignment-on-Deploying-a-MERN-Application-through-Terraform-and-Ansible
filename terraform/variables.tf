variable "aws_region" {
  description = "AWS region for the TravelMemory deployment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for resources created for this project."
  type        = string
  default     = "travelmemory"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range for the project VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR range for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "IPv4 CIDR range for the private subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability Zone shared by the public and private subnets."
  type        = string
  default     = "us-east-1a"
}

variable "admin_cidr" {
  description = "Your current public IPv4 address in CIDR notation, used only for SSH access to the web server (for example, 203.0.113.10/32)."
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type for the web and database servers."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Local path to the SSH public key used for EC2 access."
  type        = string
  default     = "~/.ssh/travelmemory-terraform.pub"
}

variable "deployment_confirmed" {
  description = "Explicit confirmation that the paid plan, credits, estimated costs, and teardown procedure were reviewed. This is a safety gate, not a spending cap."
  type        = bool
  default     = false
}
