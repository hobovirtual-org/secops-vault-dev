# Repository security

## Required GitHub settings

- Enable branch protection on `main`
- Require pull request reviews before merge
- Require status checks to pass before merge
- Enable secret scanning and push protection
- Enable Dependabot alerts and security updates

## HCP Terraform expectations

- Store `hcp_terraform_organization` and `hcp_terraform_workspace` as workspace variables or provide them through `.tfvars` files outside version control
- Prefer HCP Terraform dynamic AWS credentials over long-lived static keys
- Mark sensitive Terraform variables as sensitive in HCP Terraform
