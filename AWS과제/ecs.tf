resource "aws_ecs_cluster" "app_cluster" {
  name = "app-cluster"
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_ecs_task_definition" "green_task" {
  family                   = "green-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "green-app"
      image     = "${aws_ecr_repository.green.repository_url}:v1.0.0"
      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]
      environment = [
        {
          name  = "ENV"
          value = "production"
        }
      ]
    }
  ])
}
resource "aws_lb" "app_alb" {
  name               = "internal-app-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = [aws_subnet.app_private.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "green_tg" {
  name     = "green-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.app.id
  target_type = "ip"
  health_check {
    path = "/health"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "green_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_tg.arn
  }
}
resource "aws_ecs_service" "green_service" {
  name            = "green-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.green_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.app_private.id]
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.green_tg.arn
    container_name   = "green-app"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.green_listener
  ]
}
