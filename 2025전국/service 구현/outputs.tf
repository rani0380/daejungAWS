output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID"
  value       = aws_lb.main.zone_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.product.name
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    for service in local.services :
    service => aws_ecr_repository.services[service].repository_url
  }
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "service_endpoints" {
  description = "Service endpoints"
  value = {
    user    = "http://${aws_lb.main.dns_name}/v1/user"
    product = "http://${aws_lb.main.dns_name}/v1/product"
    stress  = "http://${aws_lb.main.dns_name}/v1/stress"
  }
}