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
