# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# Target Groups
resource "aws_lb_target_group" "user" {
  name     = "${local.name_prefix}-user-tg"
  port     = local.ports.app
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "${local.name_prefix}-user-tg"
  }
}

resource "aws_lb_target_group" "product" {
  name     = "${local.name_prefix}-product-tg"
  port     = local.ports.app
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "${local.name_prefix}-product-tg"
  }
}

resource "aws_lb_target_group" "stress" {
  name     = "${local.name_prefix}-stress-tg"
  port     = local.ports.app
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "${local.name_prefix}-stress-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

# Listener Rules
resource "aws_lb_listener_rule" "user" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user.arn
  }
  
  condition {
    path_pattern {
      values = ["/v1/user*"]
    }
  }
}

resource "aws_lb_listener_rule" "product" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product.arn
  }
  
  condition {
    path_pattern {
      values = ["/v1/product*"]
    }
  }
}

resource "aws_lb_listener_rule" "stress" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 300
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stress.arn
  }
  
  condition {
    path_pattern {
      values = ["/v1/stress*"]
    }
  }
}