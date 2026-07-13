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
