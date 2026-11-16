# DB subnet group - tells RDS to place the database only in the two isolated
# data-tier subnets (one per Availability Zone). No route to the internet exists there.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.data_1.id, aws_subnet.data_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# MySQL database for the data tier
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true # encrypted at rest with the default AWS-managed KMS key

  db_name  = var.db_name
  username = var.db_username

  # RDS generates the master password and stores it in AWS Secrets Manager.
  # No password ever appears in the code, the state file, or Git.
  manage_master_user_password = true

  # Network isolation: private subnets only, reachable only via the data security group
  # (which allows port 3306 from the application tier and nothing else).
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.data.id]
  publicly_accessible    = false

  # High availability: synchronous standby in the second AZ with automatic failover
  multi_az = var.db_multi_az

  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  # Demo settings so `terraform destroy` works cleanly.
  # For a real workload: skip_final_snapshot = false and deletion_protection = true.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-mysql"
    Tier = "data"
  }
}
