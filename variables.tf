variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "multi-tier"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_engine_version" {
  description = "MySQL engine version (8.4 is the current LTS; 8.0 left RDS standard support on 31 Jul 2026)"
  type        = string
  default     = "8.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username (the password is generated and stored in Secrets Manager)"
  type        = string
  default     = "admin"
}

variable "db_multi_az" {
  description = "Run a standby in a second AZ. Set to false for a cheaper, faster demo."
  type        = bool
  default     = true
}
