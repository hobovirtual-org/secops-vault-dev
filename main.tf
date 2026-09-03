data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "vault_host" {
  most_recent = true
  owners      = [var.ami_owner_account_id]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = {
    a = {
      availability_zone = data.aws_availability_zones.available.names[0]
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0)
    }
    b = {
      availability_zone = data.aws_availability_zones.available.names[1]
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
    }
  }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Public access to the Vault ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Vault to instance"
    from_port   = var.vault_listener_port
    to_port     = var.vault_listener_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "vault" {
  name        = "${local.name_prefix}-vault"
  description = "Restrict access to Vault and SSH"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Vault from ALB"
    from_port       = var.vault_listener_port
    to_port         = var.vault_listener_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "HTTPS egress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP egress for package installation"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-vault-sg"
  }
}

data "aws_route53_zone" "vault" {
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "vault" {
  domain_name       = var.vault_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-vault-cert"
  }
}

resource "aws_route53_record" "vault_validation" {
  for_each = {
    for dvo in aws_acm_certificate.vault.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.vault.zone_id
}

resource "aws_acm_certificate_validation" "vault" {
  certificate_arn         = aws_acm_certificate.vault.arn
  validation_record_fqdns = [for record in aws_route53_record.vault_validation : record.fqdn]
}

resource "aws_lb" "vault" {
  name               = replace(substr("${local.name_prefix}-vault", 0, 32), "/[^a-zA-Z0-9-]/", "-")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name = "${local.name_prefix}-vault-alb"
  }
}

resource "aws_lb_target_group" "vault" {
  name        = replace(substr("${local.name_prefix}-vault", 0, 32), "/[^a-zA-Z0-9-]/", "-")
  port        = var.vault_listener_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    matcher             = "200,429,472,473"
    path                = "/v1/sys/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }

  tags = {
    Name = "${local.name_prefix}-vault-tg"
  }
}

resource "aws_lb_target_group_attachment" "vault" {
  target_group_arn = aws_lb_target_group.vault.arn
  target_id        = aws_instance.vault.id
  port             = var.vault_listener_port
}

resource "aws_lb_listener" "vault_https" {
  load_balancer_arn = aws_lb.vault.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.vault.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}

resource "aws_route53_record" "vault" {
  name    = var.vault_domain
  type    = "A"
  zone_id = data.aws_route53_zone.vault.zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_lb.vault.dns_name
    zone_id                = aws_lb.vault.zone_id
  }
}

resource "aws_kms_key" "vault_unseal" {
  description             = "KMS key for Vault auto-unseal"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${local.name_prefix}-vault-unseal"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/${local.name_prefix}-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

resource "aws_iam_role" "ec2" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

resource "aws_iam_role_policy" "vault_unseal" {
  name = "${local.name_prefix}-vault-unseal"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.vault_unseal.arn
      }
    ]
  })
}

# Vault AWS auth method — Vault calls iam:GetRole / iam:GetUser to resolve
# bound_iam_principal_arns to internal IDs when roles are registered.
# Also needs sts:GetCallerIdentity to verify incoming EC2 login requests.
resource "aws_iam_role_policy" "vault_aws_auth" {
  name = "${local.name_prefix}-vault-aws-auth"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VaultAWSAuthResolveARN"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetUser",
        ]
        Resource = "*"
      },
      {
        Sid      = "VaultAWSAuthVerifyLogin"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "vault" {
  ami                    = data.aws_ami.vault_host.id
  instance_type          = var.instance_type
  private_ip             = local.vault_private_ip
  subnet_id              = aws_subnet.public["a"].id
  vpc_security_group_ids = [aws_security_group.vault.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.existing_key_pair_name

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region               = var.aws_region
    kms_key_id               = aws_kms_key.vault_unseal.key_id
    vault_domain             = var.vault_domain
    vault_edition            = var.vault_edition
    vault_enterprise_license = var.vault_enterprise_license == null ? "" : var.vault_enterprise_license
    vault_listener_address   = local.vault_private_ip
    vault_listener_port      = var.vault_listener_port
    vault_package            = var.vault_edition == "enterprise" ? "vault-enterprise" : "vault"
    vault_version            = var.vault_edition == "enterprise" ? var.vault_enterprise_version : var.vault_version
  })

  tags = {
    Name = "${local.name_prefix}-vault"
  }
}
