output "ami_id" {
  description = "AMI selected for the Vault EC2 instance."
  value       = data.aws_ami.vault_host.id
}

output "vault_private_ip" {
  description = "Private IP address of the Vault EC2 instance."
  value       = aws_instance.vault.private_ip
}

output "vault_alb_dns_name" {
  description = "Native AWS DNS name of the public Application Load Balancer."
  value       = aws_lb.vault.dns_name
}

output "vault_url" {
  description = "Public Vault URL that clients should use."
  value       = "https://${var.vault_domain}"
}

output "vault_public_ip" {
  description = "Public IP address of the Vault EC2 instance."
  value       = aws_instance.vault.public_ip
}

output "vault_ssh_command" {
  description = "Example SSH command to connect to the Vault EC2 instance using ssh_private_key_path."
  value       = format("ssh -i %s ec2-user@%s", var.ssh_private_key_path, aws_instance.vault.public_dns)
}

output "vpc_id" {
  description = "ID of the dedicated VPC."
  value       = aws_vpc.this.id
}
