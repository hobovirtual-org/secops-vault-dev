locals {
  name_prefix      = "${var.project_name}-${var.environment}"
  vault_private_ip = cidrhost(cidrsubnet(var.vpc_cidr, 8, 0), 10)
}
