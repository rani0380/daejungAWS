# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(local.services)
  
  name              = "/ecs/${local.name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name    = "${local.name_prefix}-${each.key}-logs"
    Service = each.key
  }
}

# User Service Task Definition
resource "aws_ecs_task_definition" "user" {
  family                   = "${local.name_prefix}-user"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  cpu                      = "256"
  memory                   = "512"
  
  container_definitions = jsonencode([
    {
      name  = "user"
      image = "${aws_ecr_repository.services["user"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = local.ports.app
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.main.endpoint
        },
        {
          name  = "DB_NAME"
          value = aws_db_instance.main.db_name
        },
        {
          name  = "DB_USER"
          value = aws_db_instance.main.username
        },
        {
          name  = "DB_PASSWORD"
          value = aws_db_instance.main.password
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["user"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/healthcheck || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])
}

# Product Service Task Definition
resource "aws_ecs_task_definition" "product" {
  family                   = "${local.name_prefix}-product"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.product_task.arn
  cpu                      = "256"
  memory                   = "512"
  
  container_definitions = jsonencode([
    {
      name  = "product"
      image = "${aws_ecr_repository.services["product"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = local.ports.app
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "DYNAMODB_TABLE"
          value = aws_dynamodb_table.product.name
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["product"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/healthcheck || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])
}

# Stress Service Task Definition
resource "aws_ecs_task_definition" "stress" {
  family                   = "${local.name_prefix}-stress"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  cpu                      = "256"
  memory                   = "512"
  
  container_definitions = jsonencode([
    {
      name  = "stress"
      image = "${aws_ecr_repository.services["stress"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = local.ports.app
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["stress"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/healthcheck || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])
}