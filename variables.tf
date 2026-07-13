variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to access Vault over HTTPS and SSH."

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "Provide at least one allowed CIDR block."
  }
}

variable "ami_name_pattern" {
  type        = string
  description = "Name glob pattern for the approved base AMI. most_recent = true selects the newest match. The date suffix is matched by the trailing *."
  default     = "hc-base-rhel-9-x86_64-*"
}

variable "ami_owner_account_id" {
  type        = string
  description = "AWS account ID of the account that publishes the approved base AMI. Do not commit real values — set via tfvars or HCP Terraform workspace variable."
}

variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name used in resource naming and workspace tagging."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "sandbox"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, sandbox."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the Vault server."
  default     = "t3.small"
}

variable "project_name" {
  type        = string
  description = "Project name used in resource naming."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB for the Vault EC2 instance."
  default     = 20
}

variable "existing_key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name to attach to the Vault instance."
}

variable "ssh_private_key_path" {
  type        = string
  description = "Local path to the SSH private key used with the example vault_ssh_command output and helper scripts."
  default     = "linux.pem"
}

variable "route53_zone_name" {
  type        = string
  description = "Public Route53 hosted zone name that contains vault_domain, for example example.com."
}

variable "vault_domain" {
  type        = string
  description = "Fully qualified domain name to publish in Route53 and associate with the ACM certificate and ALB."
}

variable "vault_edition" {
  type        = string
  description = "Vault edition to install. 'enterprise' installs vault-enterprise, 'community' installs vault."
  default     = "enterprise"

  validation {
    condition     = contains(["enterprise", "community"], var.vault_edition)
    error_message = "vault_edition must be 'enterprise' or 'community'."
  }
}

variable "vault_listener_port" {
  type        = number
  description = "Port reserved for Vault ingress rules and local service binding."
  default     = 8200
}

variable "vault_enterprise_license" {
  type        = string
  description = "Vault Enterprise license contents. Set as a sensitive HCP Terraform workspace variable or in local non-committed tfvars only when using enterprise edition."
  default     = null
  sensitive   = true
}

variable "vault_enterprise_version" {
  type        = string
  description = "Vault Enterprise RPM version to install from the official HashiCorp repository. Enterprise builds use the +ent suffix."
  default     = "2.0.3+ent"
}

variable "vault_version" {
  type        = string
  description = "Vault Community RPM version to install from the official HashiCorp repository."
  default     = "1.21.4"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the dedicated VPC."
  default     = "10.42.0.0/16"
}
