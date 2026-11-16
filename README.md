# AWS Multi-Tier Architecture with Terraform

A highly available, three-tier AWS architecture defined entirely as code. One `terraform apply` builds the network, load balancer, auto-scaled application tier and a private, encrypted MySQL database (21 resources). One `terraform destroy` removes everything.

## Architecture

```
                         Internet
                            |
                    Internet Gateway
                            |
  +------------------- VPC 10.0.0.0/16 --------------------+
  |                                                         |
  |   AZ us-east-1a                    AZ us-east-1b        |
  |                                                         |
  |   Public  10.0.1.0/24    <--  Application Load  -->  Public  10.0.2.0/24
  |                               Balancer (HTTP :80)       |
  |                                     |                   |
  |   App     10.0.11.0/24   EC2 Auto Scaling Group    App   10.0.12.0/24
  |                          (min 2 / max 4, t3.micro)      |
  |                                     |  MySQL :3306      |
  |   Data    10.0.21.0/24   RDS MySQL 8.4 (private)  Data  10.0.22.0/24
  |                                                         |
  +---------------------------------------------------------+
```

| Tier | Resources | Subnets |
|---|---|---|
| Presentation | Application Load Balancer, target group, HTTP listener | Public (2 AZs) |
| Application | Launch template, Auto Scaling Group of EC2 instances | Private app (2 AZs) |
| Data | RDS for MySQL 8.4, DB subnet group | Private data (2 AZs) |

## Security design

- **Security-group chaining:** the load balancer accepts HTTP from the internet; the app tier accepts HTTP **only from the load balancer's security group**; the database accepts MySQL (3306) **only from the app tier's security group**.
- **No direct internet path to the app or data tiers:** only the public subnets are associated with the route table that has a route to the Internet Gateway. App and data subnets have local-only routing.
- **Database:** not publicly accessible, encrypted at rest, automated backups enabled.
- **No secrets in code or state:** RDS generates the master password and stores it in AWS Secrets Manager (`manage_master_user_password = true`).
- **IMDSv2** is used by the instance bootstrap script to read instance metadata.

## Prerequisites

- Terraform 1.x and the AWS provider `~> 6.0` (pinned by `.terraform.lock.hcl`)
- AWS CLI configured with credentials for the target account (`aws sts get-caller-identity` should succeed)
- Permissions to create VPC, EC2, ELB, Auto Scaling, RDS and Secrets Manager resources

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

For a cheaper, faster test (single-AZ database, free-tier friendly):

```bash
terraform apply -var="db_multi_az=false"
```

The RDS instance is the slowest resource; expect several minutes.

## Verify

```bash
terraform output alb_dns_name
```

Open `http://<alb_dns_name>` (HTTP, not HTTPS). The page shows the serving instance, its Availability Zone and the database status:

```
Multi-Tier Architecture
Served from ip-10-0-11-xx.ec2.internal in us-east-1a
MySQL data tier: reachable
```

To see both Availability Zones:

```bash
for i in 1 2 3 4 5 6 7 8; do curl -s http://<alb_dns_name> | grep -o "Served from [^<]*"; done
```

"MySQL data tier: reachable" comes from a TCP check on port 3306 run by each app instance at boot, which confirms the network path and security-group rules between the app and data tiers.

## Destroy

```bash
terraform destroy
# or, if you applied with the variable override:
terraform destroy -var="db_multi_az=false"
```

The load balancer, EC2 instances and RDS instance are billed by the hour while running.

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Deployment region |
| `project_name` | `multi-tier` | Name prefix for all resources |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `db_engine_version` | `8.4` | MySQL version (8.4 LTS; 8.0 left RDS standard support on 31 Jul 2026) |
| `db_instance_class` | `db.t3.micro` | RDS instance class |
| `db_name` | `appdb` | Initial database name |
| `db_username` | `admin` | Master user (password is generated and kept in Secrets Manager) |
| `db_multi_az` | `true` | Synchronous standby in a second AZ with automatic failover |

## Outputs

`vpc_id`, `alb_dns_name`, `public_subnet_ids`, `app_subnet_ids`, `data_subnet_ids`, `db_endpoint`, `db_secret_arn`

## Repository layout

| File | Purpose |
|---|---|
| `providers.tf` | Terraform and AWS provider configuration |
| `variables.tf` | Input variables |
| `vpc.tf` | VPC, Internet Gateway, six subnets, public route table |
| `security_groups.tf` | ALB, app and data security groups |
| `alb.tf` | Load balancer, target group, listener |
| `asg.tf` | AMI lookup, launch template, Auto Scaling Group |
| `rds.tf` | DB subnet group and MySQL instance |
| `outputs.tf` | Output values |

## Troubleshooting

- **`InvalidClientTokenId` / "security token is invalid":** stale or wrong AWS credentials. Run `env | grep AWS`, clear old variables, remove any old `aws_session_token` from `~/.aws/credentials`, then check `aws sts get-caller-identity`.
- **Free-tier accounts:** use `db_multi_az=false`. If RDS rejects the backup setting, lower `backup_retention_period` in `rds.tf` to `1`.
- **502/503 right after apply:** wait two to three minutes for instances to pass health checks.

## Known limitations and next steps

This is a POC project, deliberately small. Before treating it as production it would need:

- HTTPS on the load balancer (ACM certificate, redirect from port 80)
- Remote state (S3 backend with locking) instead of local state
- Explicit private route tables for the app and data tiers (isolation currently relies on the VPC main route table having no internet route)
- NAT gateway or VPC endpoints (for example Secrets Manager, SSM) if the app tier needs outbound access
- A real application in place of the demo web page
- Reusable modules and per-environment variable files
- CloudWatch alarms and a scaling policy for the Auto Scaling Group
