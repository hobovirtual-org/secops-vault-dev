variable "hcp_terraform_organization" {
  type        = string
  description = "HCP Terraform organization name."

  validation {
    condition     = var.hcp_terraform_organization != "replace-with-your-org"
    error_message = "hcp_terraform_organization must be set to a real HCP Terraform organization name."
  }
}

variable "hcp_terraform_workspace" {
  type        = string
  description = "HCP Terraform workspace name to create/update."
  default     = "vault-ec2"
}

variable "environment" {
  type        = string
  description = "Environment name used in workspace tagging."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "sandbox"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, sandbox."
  }
}

variable "project_name" {
  type        = string
  description = "Project name used in workspace tagging."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "application" {
  type        = string
  description = "Application or service name used for workspace tagging."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.application))
    error_message = "application must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "owner" {
  type        = string
  description = "Owning team or approved contact identifier used for workspace tagging."

  validation {
    condition     = can(regex("^[A-Za-z0-9._@-]+$", var.owner))
    error_message = "owner must contain only letters, numbers, dot, underscore, at sign, and hyphen."
  }
}

variable "support_team" {
  type        = string
  description = "Support team identifier used for workspace tagging."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.support_team))
    error_message = "support_team must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "cost_center" {
  type        = string
  description = "Cost center tag value, for example cc-104."

  validation {
    condition     = can(regex("^[a-z]{2,}-[0-9]{2,}$", var.cost_center))
    error_message = "cost_center must look like cc-104."
  }
}

variable "data_classification" {
  type        = string
  description = "Data classification tag value used for workspace tagging."

  validation {
    condition     = contains(["public", "internal", "confidential", "pii"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, pii."
  }
}

variable "compliance" {
  type        = set(string)
  description = "Compliance frameworks that apply to this deployment. Use an empty set for none."
  default     = []

  validation {
    condition = alltrue([
      for value in var.compliance : contains(["hipaa", "pci-dss", "soc2", "none"], value)
    ])
    error_message = "compliance values must be chosen from: hipaa, pci-dss, soc2, none."
  }
}

variable "cloud_provider" {
  type        = string
  description = "Cloud provider tag value for the workspace."
  default     = "aws"

  validation {
    condition     = contains(["aws", "azure", "gcp", "other"], var.cloud_provider)
    error_message = "cloud_provider must be one of: aws, azure, gcp, other."
  }
}

# ── Root module workspace variables ─────────────────────────────────────────

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to the Vault instance. Written to the workspace as a Terraform variable."
}

variable "ami_owner_account_id" {
  type        = string
  description = "AWS account ID that owns the approved base AMI."
}

variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-east-1"
}

variable "existing_key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name to attach to the Vault instance."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the Vault server."
  default     = "t3.small"
}

variable "route53_zone_name" {
  type        = string
  description = "Public Route53 hosted zone name that contains vault_domain."
}

variable "ssh_private_key_path" {
  type        = string
  description = "Local path to the SSH private key used with the vault_ssh_command output."
  default     = "linux.pem"
}

variable "vault_domain" {
  type        = string
  description = "Fully qualified domain name to publish in Route53 and associate with the ACM certificate and ALB."
}

variable "vault_edition" {
  type        = string
  description = "Vault edition: 'enterprise' or 'community'."
  default     = "enterprise"

  validation {
    condition     = contains(["enterprise", "community"], var.vault_edition)
    error_message = "vault_edition must be 'enterprise' or 'community'."
  }
}

variable "vault_enterprise_license" {
  type        = string
  description = "Vault Enterprise license string. Stored as a sensitive workspace variable. Leave null for community edition."
  default     = null
  sensitive   = true
}
