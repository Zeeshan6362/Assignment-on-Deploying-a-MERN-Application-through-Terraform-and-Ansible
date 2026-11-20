data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "travelmemory" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-key"
  })
}

locals {
  ec2_roles = toset(["web", "database"])
}

resource "aws_iam_role" "ec2" {
  for_each = local.ec2_roles

  name = "${var.project_name}-${each.key}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-ec2-role"
    Tier = each.key
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  for_each = local.ec2_roles

  role       = aws_iam_role.ec2[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  for_each = local.ec2_roles

  name = "${var.project_name}-${each.key}-instance-profile"
  role = aws_iam_role.ec2[each.key].name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}-instance-profile"
    Tier = each.key
  })
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "SSH from the administrator and public HTTP/API access for TravelMemory."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from administrator's current public IPv4 address"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Public web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TravelMemory API called directly by browsers"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound updates and application access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web-sg"
    Tier = "public"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "MongoDB and SSH access only from the web server."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MongoDB from the web server"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "SSH from the web server for Ansible administration"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Outbound package updates through the NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-database-sg"
    Tier = "private"
  })
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.travelmemory.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2["web"].name
  associate_public_ip_address = true

  root_block_device {
    encrypted             = true
    volume_size           = 12
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web"
    Tier = "public"
  })
}

resource "aws_instance" "database" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.database.id]
  key_name               = aws_key_pair.travelmemory.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2["database"].name

  root_block_device {
    encrypted             = true
    volume_size           = 12
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-database"
    Tier = "private"
  })
}
