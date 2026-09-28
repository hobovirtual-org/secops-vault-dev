terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }

  cloud {
    organization = "crenaud-org"

    workspaces {
      name = "security-vault-dev"
    }
  }
}
