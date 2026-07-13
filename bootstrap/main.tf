locals {
  owner_tag_value      = lower(replace(replace(replace(var.owner, "@", "_at_"), ".", "_"), "/", "_"))
  compliance_tag_value = length(var.compliance) == 0 ? "none" : join("_", sort(tolist(var.compliance)))

  workspace_tag_names = [
    "environment:${var.environment}",
    "project:${var.project_name}",
    "application:${var.application}",
    "owner:${local.owner_tag_value}",
    "support_team:${var.support_team}",
    "cost_center:${var.cost_center}",
    "data_classification:${var.data_classification}",
    "compliance:${local.compliance_tag_value}",
    "cloud_provider:${var.cloud_provider}",
    "automation:terraform",
  ]
}

resource "tfe_workspace" "main" {
  name         = var.hcp_terraform_workspace
  organization = var.hcp_terraform_organization
  tag_names    = local.workspace_tag_names
}

# ── Workspace variables ──────────────────────────────────────────────────────
# Non-sensitive Terraform variables required by the root module.
locals {
  workspace_vars = {
    allowed_cidr_blocks    = { value = jsonencode(var.allowed_cidr_blocks), sensitive = false }
    ami_owner_account_id   = { value = var.ami_owner_account_id, sensitive = false }
    aws_region             = { value = var.aws_region, sensitive = false }
    environment            = { value = var.environment, sensitive = false }
    existing_key_pair_name = { value = var.existing_key_pair_name, sensitive = false }
    instance_type          = { value = var.instance_type, sensitive = false }
    project_name           = { value = var.project_name, sensitive = false }
    route53_zone_name      = { value = var.route53_zone_name, sensitive = false }
    ssh_private_key_path   = { value = var.ssh_private_key_path, sensitive = false }
    vault_domain           = { value = var.vault_domain, sensitive = false }
    vault_edition          = { value = var.vault_edition, sensitive = false }
  }
}

resource "tfe_variable" "workspace" {
  for_each = local.workspace_vars

  key          = each.key
  value        = each.value.value
  category     = "terraform"
  sensitive    = each.value.sensitive
  workspace_id = tfe_workspace.main.id
}

# Sensitive variables are managed separately so the value is never stored in
# the bootstrap state in plaintext. Set vault_enterprise_license only when
# vault_edition = "enterprise".
resource "tfe_variable" "vault_enterprise_license" {
  count = var.vault_enterprise_license != null ? 1 : 0

  key          = "vault_enterprise_license"
  value        = var.vault_enterprise_license
  category     = "terraform"
  sensitive    = true
  workspace_id = tfe_workspace.main.id
}
