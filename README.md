# Vault on EC2

> HashiCorp Vault on AWS EC2, provisioned by Terraform through HCP Terraform, fronted by an Application Load Balancer with ACM-managed TLS and AWS KMS auto-unseal.

![Vault on EC2 architecture](docs/architecture.svg)

> Fresh environment bootstrap can be done with a single command: [`./scripts/init-vault.sh`](scripts/init-vault.sh).

---

## Overview

This repository provisions a complete single-node Vault environment in AWS with:

- a dedicated VPC
- two public subnets for the ALB
- a public HTTPS endpoint on [`vault_domain`](variables.tf:73)
- DNS automation in Route53
- ACM certificate issuance and renewal
- a single EC2 instance running Vault Community or Vault Enterprise
- AWS KMS auto-unseal for Vault Enterprise
- HCP Terraform-compatible workflow

The current design keeps Vault off the public internet directly:

- clients connect to the ALB over HTTPS
- the ALB forwards traffic to Vault over HTTP inside the VPC
- Vault listens on the instance private IP only
- the Vault security group only allows the Vault listener port from the ALB security group

---

## What Terraform creates

| Resource | Details |
|---|---|
| VPC | Dedicated VPC using [`vpc_cidr`](variables.tf:114) |
| Internet Gateway | Internet access for public subnets |
| Public subnets | Two subnets across two AZs for the ALB in [`main.tf`](main.tf:53) |
| Public route table | Default route to the internet gateway |
| ALB security group | Allows inbound HTTPS from the internet and forwards only to the Vault listener port |
| Vault security group | Allows Vault traffic only from the ALB security group and SSH only from [`allowed_cidr_blocks`](variables.tf:1) |
| Route53 hosted zone lookup | Finds the existing public hosted zone from [`route53_zone_name`](variables.tf:68) |
| ACM certificate | DNS-validated certificate for [`vault_domain`](variables.tf:73) |
| Route53 validation records | DNS validation records for ACM |
| Application Load Balancer | Public ALB with HTTPS listener and TLS 1.3 policy in [`main.tf`](main.tf:219) |
| ALB target group | HTTP target group with Vault health checks on `/v1/sys/health` |
| Route53 alias record | Alias A record from `vault_domain` to the ALB |
| KMS key and alias | Auto-unseal key with key rotation enabled |
| EC2 IAM role and instance profile | Grants the instance access only to the KMS unseal key |
| EC2 instance | Approved RHEL 9 AMI, fixed private IP, encrypted root volume, IMDSv2 required |
| Vault bootstrap | Installs Vault and writes config through [`user_data.sh.tftpl`](user_data.sh.tftpl) |

---

## Architecture

### Traffic flow

1. A client connects to `https://vault_domain`
2. Route53 resolves the hostname to the ALB
3. The ALB terminates TLS using an ACM certificate
4. The ALB forwards the request to the EC2 instance over HTTP on [`vault_listener_port`](variables.tf:89)
5. Vault serves traffic from its fixed private IP
6. For Enterprise, Vault uses AWS KMS for auto-unseal

### Why this design

- **TLS is managed by AWS** using ACM, which removes instance-side certificate management
- **Vault is not exposed directly** because it binds to a private IP and only accepts the listener port from the ALB security group
- **KMS auto-unseal avoids unseal operations after restart** while keeping key material out of instance bootstrap logic
- **A fixed private IP avoids self-reference problems** when generating the Vault listener configuration

---

## Requirements

### Tools

| Tool | Version | Notes |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | `>= 1.9.0` | Used locally or through HCP Terraform |
| [HCP Terraform](https://app.terraform.io) | Current | Recommended execution environment |
| AWS account | Current | Must contain or have access to the target Route53 hosted zone |

### AWS capabilities needed

The Terraform credentials must be able to manage:

- EC2, VPC, subnets, route tables, internet gateway, security groups, and AMI lookup
- IAM roles, inline policies, and instance profiles
- ACM certificates and Route53 validation records
- ALB resources and target groups
- KMS keys and aliases

### DNS requirement

[`vault_domain`](variables.tf:73) must be inside the hosted zone identified by [`route53_zone_name`](variables.tf:68), and that hosted zone must be in the same AWS account used by Terraform.

---

## Quick start

### 1. Create a variable file

Copy [`terraform.tfvars.example`](terraform.tfvars.example) to a local non-committed tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then set at least:

- [`project_name`](variables.tf:45)
- [`ami_owner_account_id`](variables.tf:17)
- [`existing_key_pair_name`](variables.tf:61)
- [`ssh_private_key_path`](variables.tf:66)
- [`route53_zone_name`](variables.tf:72)
- [`vault_domain`](variables.tf:77)
- [`allowed_cidr_blocks`](variables.tf:1)

If using Vault Enterprise, also set [`vault_enterprise_license`](variables.tf:99) as a sensitive HCP Terraform variable or in your local untracked tfvars file.

### 2. Authenticate

For local CLI-driven runs:

```bash
terraform login
terraform init
```

For HCP Terraform, configure the workspace and set the required variables there.

### 3. Plan and apply

```bash
terraform plan
terraform apply
```

### 4. Use the outputs

After apply, use:

- [`vault_url`](outputs.tf:16) for the public Vault URL
- [`vault_alb_dns_name`](outputs.tf:11) for direct ALB verification
- [`vault_ssh_command`](outputs.tf:26) to connect to the instance

---

## Variables

All inputs are declared in [`variables.tf`](variables.tf).

### Required variables

| Name | Description |
|---|---|
| `allowed_cidr_blocks` | CIDRs allowed to SSH to the instance |
| `ami_owner_account_id` | AWS account ID that owns the approved base AMI |
| `existing_key_pair_name` | Existing EC2 key pair name |
| `project_name` | Naming prefix for AWS resources |
| `route53_zone_name` | Public Route53 hosted zone name |
| `vault_domain` | Public DNS name for Vault |

### Important optional variables

| Name | Default | Notes |
|---|---|---|
| `ami_name_pattern` | `hc-base-rhel-9-x86_64-*` | Used with `most_recent = true` to select the newest approved image |
| `aws_region` | `us-east-1` | Region for all resources |
| `environment` | `dev` | Validated as `dev`, `staging`, `prod`, or `sandbox` |
| `instance_type` | `t3.small` | EC2 instance type |
| `root_volume_size` | `20` | Root disk size in GiB |
| `vault_edition` | `enterprise` | `enterprise` or `community` |
| `vault_enterprise_license` | `null` | Sensitive, Enterprise only |
| `vault_enterprise_version` | `2.0.3+ent` | Enterprise package version |
| `vault_listener_port` | `8200` | Listener and target group port |
| `ssh_private_key_path` | `linux.pem` | Local path used by [`vault_ssh_command`](outputs.tf:26) |
| `vault_version` | `1.21.4` | Community package version |
| `vpc_cidr` | `10.42.0.0/16` | VPC CIDR |

---

## Outputs

The project exposes these outputs in [`outputs.tf`](outputs.tf):

| Output | Description |
|---|---|
| `ami_id` | AMI selected for the instance |
| `vault_alb_dns_name` | Native AWS DNS name of the ALB |
| `vault_private_ip` | Private IP of the Vault instance |
| `vault_public_ip` | Public IP of the instance |
| `vault_url` | Public Vault URL, `https://vault_domain` |
| `vault_ssh_command` | Example SSH command for the instance using [`ssh_private_key_path`](variables.tf:68) |
| `vpc_id` | Dedicated VPC ID |

---

## Vault edition behavior

[`vault_edition`](variables.tf:78) controls which package and configuration are used.

| Edition | Package | Version variable | Storage | Notes |
|---|---|---|---|---|
| `enterprise` | `vault-enterprise` | [`vault_enterprise_version`](variables.tf:102) | `raft` | Requires [`vault_enterprise_license`](variables.tf:95) |
| `community` | `vault` | [`vault_version`](variables.tf:108) | `file` | Intended for development and testing |

Enterprise uses:

- `license_path` in the Vault config
- `storage "raft"`
- `seal "awskms"`

Community uses file storage and does not use the Enterprise license path.

---

## TLS and DNS

TLS and DNS are fully automated by Terraform:

- [`aws_acm_certificate.vault`](main.tf:184) requests the certificate
- [`aws_route53_record.vault_validation`](main.tf:197) creates DNS validation records
- [`aws_acm_certificate_validation.vault`](main.tf:214) completes validation
- [`aws_lb_listener.vault_https`](main.tf:261) terminates HTTPS at the ALB
- [`aws_route53_record.vault`](main.tf:274) creates the alias A record for the vanity domain

This means:

- no Certbot on the instance
- no instance-side public certificate files
- automatic ACM renewal

---

## Vault initialisation and operations

### Important

This project still avoids automatic initialization during instance bootstrap, but it now includes an operator-side helper script so you do not have to type the initialization commands manually every time you create a fresh environment.

The security boundary remains the same:

- Terraform and cloud-init start Vault
- the helper script initializes Vault exactly once
- bootstrap material is written only to a local file on the operator machine
- AWS KMS handles future unseal operations automatically

### One-command initialization

Use [`scripts/init-vault.sh`](scripts/init-vault.sh) after [`terraform apply`](terraform.tf:1):

```bash
./scripts/init-vault.sh
```

What the script does:

1. Reads [`vault_ssh_command`](outputs.tf:26) from Terraform output unless `VAULT_SSH_COMMAND` is set
2. Connects to the instance over SSH
3. Checks whether Vault is already initialized
4. Runs `vault operator init -format=json` only when needed
5. Stores the JSON output locally in `.secrets/vault-init.json`
6. Prints a final [`vault status`](https://developer.hashicorp.com/vault/docs/commands/status)

### Local secret handling

The helper writes bootstrap output to:

- `.secrets/<workspace>-<vault-domain>-vault-init.json`

Treat that file as highly sensitive:

- move it to an approved secret manager or encrypted offline storage immediately
- do not commit it
- remove it from your workstation when you are done

### Export a ready-to-use Vault shell environment

After initialization, you can populate your local shell with [`VAULT_ADDR`](https://developer.hashicorp.com/vault/docs/commands#environment-variables) and [`VAULT_TOKEN`](https://developer.hashicorp.com/vault/docs/commands#environment-variables) using [`scripts/vault-env.sh`](scripts/vault-env.sh):

```bash
eval "$(./scripts/vault-env.sh)"
```

Then you can immediately run commands such as:

```bash
vault status
vault secrets list
```

### Manual fallback

If you ever need to initialize by hand, connect with [`vault_ssh_command`](outputs.tf:26) and run:

```bash
export VAULT_ADDR="http://$(curl -sf http://169.254.169.254/latest/meta-data/local-ipv4):8200"
vault operator init
```

### Verify service and auto-unseal

Useful checks on the instance:

```bash
sudo systemctl status vault
sudo tail -n 100 /var/log/vault-bootstrap.log
vault status
```

For Enterprise with KMS auto-unseal, [`vault status`](https://developer.hashicorp.com/vault/docs/commands/status) should report `Seal Type: awskms` after initialization is complete.

---

## Security posture

| Control | Current implementation |
|---|---|
| Public TLS | ACM certificate on the ALB |
| Restricted backend access | Vault listener is reachable only from the ALB security group |
| No direct public Vault listener | Vault binds to the instance private IP only |
| Secure metadata access | IMDSv2 enforced in [`aws_instance.vault`](main.tf:348) |
| Encrypted storage | Root EBS volume uses encryption and `gp3` |
| No hardcoded secrets in code | Sensitive values come from variables |
| Auto-unseal without embedded keys | KMS key and IAM policy are provisioned in Terraform |
| Minimal IAM scope | Instance role is scoped to the KMS unseal key |

---

## HCP Terraform notes

The Terraform configuration runs inside HCP Terraform. The workspace and its variable set are managed outside this repository.

Recommended setup:

1. Set required variables in the workspace or an attached variable set
2. Mark [`vault_enterprise_license`](variables.tf:99) as sensitive if using Enterprise
3. Prefer dynamic AWS credentials instead of long-lived access keys

---

## Repository automation and Bob tooling

### GitHub automation

| File | Purpose |
|---|---|
| [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml) | Runs format and validation checks |
| [`.github/dependabot.yml`](.github/dependabot.yml) | Keeps GitHub Actions and Terraform dependencies updated |
| [`SECURITY.md`](SECURITY.md) | Repository security guidance |
| [`.gitignore`](.gitignore) | Prevents committing Terraform state, plans, and local secrets |

### Bob workspace support

- [`.bob/custom_modes.yaml`](.bob/custom_modes.yaml) defines the workspace mode used for this repository
- [`.bob/skills/`](.bob/skills/) contains imported HashiCorp-oriented Bob skills used during implementation

---

## Known limitations

| Limitation | Notes |
|---|---|
| Single Vault node | This is not an HA deployment |
| Enterprise uses single-node Raft | Good for demos and small environments, not resilient across instance loss |
| Community uses file storage | Suitable for dev/test only |
| Route53 zone must be in the same account | Cross-account DNS is not implemented |
| ALB backend is HTTP | TLS is terminated at the ALB, and backend traffic remains inside the VPC |

---

## Next improvements

Possible future enhancements, not currently implemented:

- multi-node Vault with Raft and private subnets
- SSM Session Manager instead of SSH key access
- backup and snapshot automation for Raft data
- WAF in front of the ALB
- tighter outbound security group restrictions with VPC endpoints
