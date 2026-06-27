output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "app_subnet_ids" {
  description = "IDs of the application subnets"
  value       = [aws_subnet.app_1.id, aws_subnet.app_2.id]
}

output "data_subnet_ids" {
  description = "IDs of the data subnets"
  value       = [aws_subnet.data_1.id, aws_subnet.data_2.id]
}