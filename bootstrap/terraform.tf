terraform {
  required_version = ">= 1.9.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "= 0.68.0"
    }
  }

  # This bootstrap config runs locally (or in a separate admin workspace) and
  # must NOT use the cloud block that references the workspace it is creating.
  # Run with:
  #   cd bootstrap
  #   terraform init
  #   terraform apply
  #
  # Authentication: set TFE_TOKEN to a team/organization token with workspace
  # creation rights. Never commit the token.
}
