output "workspace_id" {
  description = "HCP Terraform workspace ID."
  value       = tfe_workspace.main.id
}

output "workspace_name" {
  description = "HCP Terraform workspace name."
  value       = tfe_workspace.main.name
}

output "workspace_tag_names" {
  description = "Tag names applied to the workspace."
  value       = tfe_workspace.main.tag_names
}
