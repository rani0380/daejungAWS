# User Service
resource "aws_ecs_service" "user" {
  name            = "${local.name_prefix}-user"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user.arn
  desired_count   = 2
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.user.arn
    container_name   = "user"
    container_port   = local.ports.app
  }
  
  health_check_grace_period_seconds = 60
  
  depends_on = [aws_lb_listener.main]
}

# Product Service
resource "aws_ecs_service" "product" {
  name            = "${local.name_prefix}-product"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product.arn
  desired_count   = 2
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.product.arn
    container_name   = "product"
    container_port   = local.ports.app
  }
  
  health_check_grace_period_seconds = 60
  
  depends_on = [aws_lb_listener.main]
}

# Stress Service
resource "aws_ecs_service" "stress" {
  name            = "${local.name_prefix}-stress"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.stress.arn
  desired_count   = 1
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.stress.arn
    container_name   = "stress"
    container_port   = local.ports.app
  }
  
  health_check_grace_period_seconds = 60
  
  depends_on = [aws_lb_listener.main]
}