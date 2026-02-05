variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "skills-task3"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "competition"
}

variable "instance_type" {
  description = "ECS EC2 instance type (대회 조건)"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "log_retention_days" {
  description = "CloudWatch log retention days"
  type        = number
  default     = 7
}