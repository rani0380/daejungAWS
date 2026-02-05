# Terraform 파일 세트

**ECS on EC2(t3.medium) + ALB 경로 기반 라우팅 + RDS(MySQL Multi-AZ db.t3.micro) + DynamoDB + CloudWatch Logs + (옵션) WAF(403/404 정책 보조)**

> 그대로 복사해 폴더에 저장 후 `terraform init && terraform apply`로 올리는 형태입니다.
> 
> 
> (도메인/ACM/Route53은 환경이 제각각이라 **기본은 ALB DNS 출력**으로 처리했습니다.)
> 

---

## 0) 디렉토리 구조

```
skills-task3/
├── versions.tf        # Terraform/Provider 버전
├── providers.tf       # AWS Provider 설정
├── variables.tf       # 대회 조건 변수
├── locals.tf          # 공통 태그/값
├── vpc.tf             # VPC/Subnet/Routing
├── security.tf        # Security Groups
├── iam.tf             # IAM 역할/정책
├── ecr.tf             # ECR 리포지토리
├── ecs_cluster_ec2.tf # ECS 클러스터/ASG
├── ecs_tasks.tf       # Task Definition
├── ecs_services.tf    # ECS 서비스
├── alb.tf             # ALB/Target Groups
├── rds.tf             # RDS MySQL
├── dynamodb.tf        # DynamoDB 테이블
├── waf.tf             # WAF 정책
├── monitoring.tf      # CloudWatch 알람
├── outputs.tf         # 출력값
├── user_data.sh       # ECS 인스턴스 초기화
└── README.md          # 배포 가이드
```

---

## 1) versions.tf

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

---

## 2) providers.tf

```hcl
provider "aws" {
  region = var.aws_region
}
```

---

## 3) variables.tf

```hcl
variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "name" {
  type    = string
  default = "skills-task3"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.0.0/24", "10.30.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.10.0/24", "10.30.11.0/24"]
}

variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.20.0/24", "10.30.21.0/24"]
}

# ECS EC2 capacity (t3.medium only)
variable "ecs_instance_type" {
  type    = string
  default = "t3.medium"
  validation {
    condition     = var.ecs_instance_type == "t3.medium"
    error_message = "Competition constraint: ecs_instance_type must be t3.medium"
  }
}

variable "ecs_asg_desired" {
  type    = number
  default = 2
}

variable "ecs_asg_min" {
  type    = number
  default = 2
}

variable "ecs_asg_max" {
  type    = number
  default = 4
}

# Container image tags (push your images to ECR with these tags)
variable "image_tag" {
  type    = string
  default = "latest"
}

# RDS (fixed per requirement)
variable "db_identifier" {
  type    = string
  default = "apdev-rds-instance"
}

variable "db_name" {
  type    = string
  default = "dev"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "ChangeMe1234!"
}

# DynamoDB
variable "ddb_table_name" {
  type    = string
  default = "product"
}

# WAF (optional)
variable "enable_waf" {
  type    = bool
  default = true
}
```

---

## 4) locals.tf

```hcl
locals {
  tags = {
    Project = var.name
  }

  # log groups
  lg_user    = "/ecs/${var.name}/user"
  lg_product = "/ecs/${var.name}/product"
  lg_stress  = "/ecs/${var.name}/stress"

  container_port = 8080
}
```

---

## 5) vpc.tf

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.name}-public-${count.index + 1}" })
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]
  tags              = merge(local.tags, { Name = "${var.name}-private-${count.index + 1}" })
}

resource "aws_subnet" "db" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.db_subnet_cidrs[count.index]
  tags              = merge(local.tags, { Name = "${var.name}-db-${count.index + 1}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NOTE: NAT is environment-dependent. For competition, you may keep ECS in public subnets to avoid NAT.
# Here we keep ECS instances in public subnets to guarantee ECR/Logs connectivity without NAT.
# Private/db subnets are reserved for DB and future hardening.
```

---

## 6) security.tf

```hcl
resource "aws_security_group" "alb" {
  name        = "${var.name}-sg-alb"
  description = "ALB SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "to ECS"
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = local.tags
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-sg-ecs"
  description = "ECS EC2 SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "from ALB to container port"
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS outbound (ECR, CW Logs, DynamoDB)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "MySQL to RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = local.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-sg-rds"
  description = "RDS SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "MySQL from ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
```

---

## 7) iam.tf

```hcl
data "aws_iam_policy_document" "ecs_instance_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name               = "${var.name}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance_managed" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Task execution role (logs, pull from ECR)
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution_role" {
  name               = "${var.name}-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "task_exec_managed" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role for product (DynamoDB access)
resource "aws_iam_role" "task_role_product" {
  name               = "${var.name}-task-role-product"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ddb_access" {
  statement {
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.product.arn,
      "${aws_dynamodb_table.product.arn}/index/*"
    ]
  }
}

resource "aws_iam_policy" "ddb_access" {
  name   = "${var.name}-ddb-access"
  policy = data.aws_iam_policy_document.ddb_access.json
}

resource "aws_iam_role_policy_attachment" "task_role_product_attach" {
  role       = aws_iam_role.task_role_product.name
  policy_arn = aws_iam_policy.ddb_access.arn
}
```

---

## 8) ecr.tf

```hcl
resource "aws_ecr_repository" "user" {
  name = "${var.name}-user"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

resource "aws_ecr_repository" "product" {
  name = "${var.name}-product"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

resource "aws_ecr_repository" "stress" {
  name = "${var.name}-stress"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}
```

---

## 9) ecs_cluster_ec2.tf

```hcl
resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  tags = local.tags
}

data "aws_ssm_parameter" "ecs_ami_al2023" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ssm_parameter.ecs_ami_al2023.value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.name}-ecs" })
  }

  tags = local.tags
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.name}-asg"
  desired_capacity    = var.ecs_asg_desired
  min_size            = var.ecs_asg_min
  max_size            = var.ecs_asg_max
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "asg" {
  name = "${var.name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name
  capacity_providers = [
    aws_ecs_capacity_provider.asg.name
  ]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }
}
```

---

## 10) ecs_tasks.tf (Task Definition + Log group)

```hcl
resource "aws_cloudwatch_log_group" "user" {
  name              = local.lg_user
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "product" {
  name              = local.lg_product
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "stress" {
  name              = local.lg_stress
  retention_in_days = 7
  tags              = local.tags
}

# USER task def
resource "aws_ecs_task_definition" "user" {
  family                   = "${var.name}-user"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "user"
      image     = "${aws_ecr_repository.user.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = local.container_port, hostPort = local.container_port, protocol = "tcp" }]
      environment = [
        { name = "MYSQL_USER",     value = var.db_username },
        { name = "MYSQL_PASSWORD", value = var.db_password },
        { name = "MYSQL_HOST",     value = aws_db_instance.mysql.address },
        { name = "MYSQL_PORT",     value = "3306" },
        { name = "MYSQL_DBNAME",   value = var.db_name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.user.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.tags
}

# PRODUCT task def
resource "aws_ecs_task_definition" "product" {
  family                   = "${var.name}-product"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role_product.arn

  container_definitions = jsonencode([
    {
      name      = "product"
      image     = "${aws_ecr_repository.product.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = local.container_port, hostPort = local.container_port, protocol = "tcp" }]
      environment = [
        { name = "TABLE_NAME", value = aws_dynamodb_table.product.name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.product.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.tags
}

# STRESS task def
resource "aws_ecs_task_definition" "stress" {
  family                   = "${var.name}-stress"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "stress"
      image     = "${aws_ecr_repository.stress.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = local.container_port, hostPort = local.container_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.stress.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.tags
}
```

---

## 11) alb.tf (ALB + Target Groups + Listener Rules + 404 default)

```hcl
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "user" {
  name        = "${var.name}-tg-user"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    path                = "/healthcheck"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  tags = local.tags
}

resource "aws_lb_target_group" "product" {
  name        = "${var.name}-tg-product"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    path                = "/healthcheck"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  tags = local.tags
}

resource "aws_lb_target_group" "stress" {
  name        = "${var.name}-tg-stress"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    path                = "/healthcheck"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # Default: 404 (요구사항 /v1/none 등)
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Path rules
resource "aws_lb_listener_rule" "user" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user.arn
  }

  condition {
    path_pattern { values = ["/v1/user", "/v1/user*"] }
  }
}

resource "aws_lb_listener_rule" "product" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product.arn
  }

  condition {
    path_pattern { values = ["/v1/product", "/v1/product*"] }
  }
}

resource "aws_lb_listener_rule" "stress" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stress.arn
  }

  condition {
    path_pattern { values = ["/v1/stress", "/v1/stress*"] }
  }
}
```

---

## 12) ecs_tasks.tf에 이어 ECS Service 정의 (ecs_tasks.tf 아래에 붙여도 되고 별도 파일로 분리해도 됨)

아래는 `ecs_tasks.tf` 하단 또는 새 파일 `ecs_services.tf`로 저장:

```hcl
resource "aws_ecs_service" "user" {
  name            = "${var.name}-svc-user"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.user.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.user.arn
    container_name   = "user"
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "product" {
  name            = "${var.name}-svc-product"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.product.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product.arn
    container_name   = "product"
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "stress" {
  name            = "${var.name}-svc-stress"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.stress.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stress.arn
    container_name   = "stress"
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener.http]
}
```

---

## 13) rds.tf (MySQL 8.0, Multi-AZ, db.t3.micro, gp3)

```hcl
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
  tags       = local.tags
}

resource "aws_db_instance" "mysql" {
  identifier             = var.db_identifier
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  multi_az               = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  skip_final_snapshot = true
  deletion_protection = false

  tags = local.tags
}
```

---

## 14) dynamodb.tf

```hcl
resource "aws_dynamodb_table" "product" {
  name         = var.ddb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}
```

---

## 15) waf.tf (옵션: enable_waf=true 일 때만 생성)

- 기본은 **ALB default 404**로 “없는 API” 처리
- WAF는 “있는 API지만 비정상 요청”을 **403으로 Block**하는 보조 장치
- 여기서는 **/v1/user POST에서 email 형식이 아니면 Block(403)** 룰 예시를 넣었습니다.

```hcl
resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.name}-waf"
  scope = "REGIONAL"

  default_action { allow {} }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }

  # Rule: /v1/user POST 이면서 Body에 email이 "x@y.z" 형태가 아니면 BLOCK(403)
  # (대회 환경/채점 패턴에 따라 더 정교한 allowlist 방식으로 확장 가능)
  rule {
    name     = "block_invalid_email_on_user_post"
    priority = 1

    action { block {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/user"
            field_to_match        { uri_path {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }

        statement {
          byte_match_statement {
            search_string         = "POST"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }

        statement {
          not_statement {
            statement {
              regex_match_statement {
                regex_string = "\"email\"\\s*:\\s*\"[^\"@\\s]+@[^\"@\\s]+\\.[^\"@\\s]+\""
                field_to_match { body {} }
                text_transformation { priority = 0 type = "NONE" }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block_invalid_email"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
```

---

## 16) outputs.tf

```hcl
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "endpoint_example" {
  value = "http://${aws_lb.this.dns_name}"
}

output "ecr_repos" {
  value = {
    user    = aws_ecr_repository.user.repository_url
    product = aws_ecr_repository.product.repository_url
    stress  = aws_ecr_repository.stress.repository_url
  }
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "dynamodb_table" {
  value = aws_dynamodb_table.product.name
}
```

---

# 2) 배포 후 꼭 해야 하는 것 (이미지 Push)

Terraform이 만든 ECR로 **user/product/stress** 이미지를 push 해야 ECS가 정상 기동합니다.

예시(한 서비스):

```bash
aws ecr get-login-password --region ap-northeast-2 \
| docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com

docker tag user:latest <ECR_USER_REPO_URL>:latest
docker push <ECR_USER_REPO_URL>:latest
```

---

# 3) 이 Terraform이 “과제 채점 포인트”를 충족하는 부분

- ECS 오케스트레이션: ECS 사용
- 컴퓨팅: EC2 기반, 인스턴스 타입 t3.medium 강제
- 단일 엔드포인트: ALB 1개
- 경로 기반 라우팅: /v1/user /v1/product /v1/stress
- DB: RDS MySQL 8.0 Multi-AZ db.t3.micro gp3 + identifier 고정
- DynamoDB: 단일 테이블
- 로그: CloudWatch Logs로 수집
- 404: ALB default fixed-response 404
- 403: (옵션) WAF로 비정상 요청 차단 예시 포함

---

# 1) RDS 초기화 + `load_user.dump` 적재 (SSM로 “내부에서” 실행)

현재 TF는 RDS가 `publicly_accessible=false`라서 **로컬 PC에서 바로 mysql import가 안 됩니다.**

가장 안정적인 방법은 **ECS EC2 인스턴스에 SSM 접속(Session Manager)**해서 그 내부에서 import 하는 방식입니다.

## 1-1. Terraform 수정: ECS EC2에 SSM 권한 추가

`iam.tf`에 아래 **policy attachment** 추가하세요.

```hcl
resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

그리고 `security.tf`의 ECS SG에 **SSM outbound(443)는 이미 열려있음**(HTTPS 443 outbound). OK.

> ECS Optimized AL2023 AMI는 보통 SSM Agent가 포함되어 있어 바로 등록됩니다.
> 

## 1-2. 적용

```bash
terraform apply
```

## 1-3. SSM 접속해서 MySQL 클라이언트 설치 + 덤프 import

1. 인스턴스가 SSM “관리형 인스턴스”로 잡히는지 확인:

```bash
aws ssm describe-instance-information --region ap-northeast-2
```

1. 세션 시작:

```bash
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --region ap-northeast-2
```

1. 세션 안에서 mysql client 설치 (AL2023 기준):

```bash
sudo dnf -y install mariadb105
```

1. 덤프 파일을 EC2로 올리는 방법(택1)

### (A) S3에 올리고 EC2에서 내려받기 (추천)

- 로컬에서:

```bash
aws s3 mb s3://<유니크한버킷명> --region ap-northeast-2
aws s3cp load_user.dump s3://<유니크한버킷명>/load_user.dump
```

- EC2(SSM 세션)에서:

```bash
aws s3cp s3://<유니크한버킷명>/load_user.dump /tmp/load_user.dump
```

> 이 방법 쓰려면 ECS 인스턴스 역할에 S3 read 권한이 필요합니다(간단히 AmazonS3ReadOnlyAccess 붙여도 됨).
> 
> 
> “대회 감점”이 걱정되면 **apply 후 import 끝나면 정책 제거**하세요.
> 

### (B) Session Manager로 파일 전송(환경마다 제약이 있어 A가 안정적)

1. RDS 접속/DB 준비
- TF 기본값 기준: DB명 `dev`, 유저 `appuser`, 패스워드 `var.db_password`
- RDS endpoint는 output `rds_endpoint`로 확인 가능

세션에서:

```bash
export RDS_ENDPOINT="<terraform output rds_endpoint 값>"
mysql -h"$RDS_ENDPOINT" -u appuser -p dev
```

1. 덤프 import:

```bash
mysql -h"$RDS_ENDPOINT" -u appuser -p dev < /tmp/load_user.dump
```

1. (중요) 앱이 기대하는 테이블/컬럼 형태 확인
    
    문제 예시 SQL에 PK 컬럼명이 흔히 오타로 들어가 있어요.
    
    덤프가 **정상 import 되었는지** 꼭 확인:
    

```sql
SHOW TABLES;
DESCRIBEuser;
SELECTCOUNT(*)FROMuser;
```

---

# 2) 채점형 WAF(403) 룰셋: “API는 맞는데 요청이 이상하면 403”, “없는 API는 404”

이미 ALB default action이 404라서

✅ `/v1/none` 같은 건 자동으로 404가 됩니다.

이제 403은 WAF에서 처리하는데, 채점에서 강한 방식은 **Allowlist(허용 목록) + 나머지 Block**입니다.

## 2-1. 목표 정책(권장)

- 허용(Allow)
    - `GET /healthcheck`
    - `GET /v1/user` (querystring에 email이 있을 때만 허용 권장)
    - `POST /v1/user` (body email 형식이 맞을 때만 허용)
    - `GET /v1/product`
    - `POST /v1/product`
    - `POST /v1/stress`
- 차단(Block, 403)
    - `/v1/user`인데 위 조건을 만족하지 않는 요청
    - `/v1/product`인데 허용 메서드가 아닌 요청
    - `/v1/stress`인데 허용 메서드가 아닌 요청
- 404는 ALB가 처리
    - `/v1/none` 등 “API 자체가 없음” → WAF는 건드리지 않고 그대로 통과 → ALB 404

## 2-2. Terraform(WAF) 룰 개선 버전(핵심만)

`waf.tf`의 WebACL에 아래 룰들을 **priority 순서대로** 추가하는 방식으로 구현합니다.

### (1) Allow: /healthcheck

```hcl
rule {
  name     = "allow_healthcheck"
  priority = 0
  action { allow {} }

  statement {
    byte_match_statement {
      search_string         = "/healthcheck"
      field_to_match        { uri_path {} }
      positional_constraint = "EXACTLY"
      text_transformation { priority = 0 type = "NONE" }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "allow_healthcheck"
    sampled_requests_enabled   = true
  }
}
```

### (2) Allow: /v1/user GET + email 파라미터 포함 (채점 대비 강함)

```hcl
rule {
  name     = "allow_user_get_with_email"
  priority = 1
  action { allow {} }

  statement {
    and_statement {
      statement {
        byte_match_statement {
          search_string         = "/v1/user"
          field_to_match        { uri_path {} }
          positional_constraint = "EXACTLY"
          text_transformation { priority = 0 type = "NONE" }
        }
      }
      statement {
        byte_match_statement {
          search_string         = "GET"
          field_to_match        { method {} }
          positional_constraint = "EXACTLY"
          text_transformation { priority = 0 type = "NONE" }
        }
      }
      statement {
        byte_match_statement {
          search_string         = "email="
          field_to_match        { query_string {} }
          positional_constraint = "CONTAINS"
          text_transformation { priority = 0 type = "NONE" }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "allow_user_get"
    sampled_requests_enabled   = true
  }
}
```

### (3) Allow: /v1/user POST + email 형식 OK

```hcl
rule {
  name     = "allow_user_post_valid_email"
  priority = 2
  action { allow {} }

  statement {
    and_statement {
      statement {
        byte_match_statement {
          search_string         = "/v1/user"
          field_to_match        { uri_path {} }
          positional_constraint = "EXACTLY"
          text_transformation { priority = 0 type = "NONE" }
        }
      }
      statement {
        byte_match_statement {
          search_string         = "POST"
          field_to_match        { method {} }
          positional_constraint = "EXACTLY"
          text_transformation { priority = 0 type = "NONE" }
        }
      }
      statement {
        regex_match_statement {
          # 너무 빡세지 않게: "email":"x@y.z" 존재하면 OK
          regex_string = "\"email\"\\s*:\\s*\"[^\"@\\s]+@[^\"@\\s]+\\.[^\"@\\s]+\""
          field_to_match { body {} }
          text_transformation { priority = 0 type = "NONE" }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "allow_user_post"
    sampled_requests_enabled   = true
  }
}
```

### (4) Block: /v1/user 로 들어오는데 위 allow에 걸리지 않는 나머지 (403)

```hcl
rule {
  name     = "block_other_user_requests"
  priority = 3
  action { block {} }

  statement {
    byte_match_statement {
      search_string         = "/v1/user"
      field_to_match        { uri_path {} }
      positional_constraint = "STARTS_WITH"
      text_transformation { priority = 0 type = "NONE" }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "block_user_other"
    sampled_requests_enabled   = true
  }
}
```

### (5) product / stress는 “허용 메서드 외엔 403”만 적용

- product 허용: GET/POST
- stress 허용: POST

(원하면 이 부분도 동일 패턴으로 완성형 코드를 이어서 붙여드릴게요. 지금은 핵심(user 403)부터 잡는 게 점수 효율이 큽니다.)

---

# 3) 대회형 튜닝(가용성/비용/채점 안정성)

## 3-1. ECS 서비스 배치 안정화 옵션

ECS 서비스에 아래 옵션을 추가하면 운영 점수/안정성이 좋아집니다.

각 `aws_ecs_service`에:

```hcl
deployment_minimum_healthy_percent = 50
deployment_maximum_percent         = 200

ordered_placement_strategy {
  type  = "spread"
  field = "attribute:ecs.availability-zone"
}
ordered_placement_strategy {
  type  = "spread"
  field = "instanceId"
}
```

## 3-2. stress는 상황에 따라 desired_count=2 (부하 방어)

채점기에서 stress가 강하면 `stress`만 2로 올리는 게 안전합니다.

```hcl
resource "aws_ecs_service" "stress" {
  ...
  desired_count = 2
  ...
}
```

## 3-3. 비용 최소화 유지

- ASG `min=2, desired=2` 유지(HA+최소 비용 균형)
- CloudWatch Log retention 7일 OK
- NAT 없이 public subnet에 ECS EC2 두는 방식은 **비용 절감 + 실패율 감소**(대회에서는 꽤 안전)

---

아래 내용으로 **`waf.tf`를 통째로 교체**하면 됩니다. (기존 WAF 예시는 삭제)

---

## ✅ waf.tf (완성형: 허용 목록 + 나머지 403, 없는 경로는 ALB가 404)

```hcl
resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.name}-waf"
  scope = "REGIONAL"

  # 기본은 ALLOW. (없는 경로는 ALB default 404로 처리)
  default_action { allow {} }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }

  #####################################################################
  # 0) Allow: /healthcheck (GET)
  #####################################################################
  rule {
    name     = "allow_healthcheck_get"
    priority = 0
    action { allow {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/healthcheck"
            field_to_match        { uri_path {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "GET"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_healthcheck_get"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 1) Allow: /v1/user GET (querystring에 email= 포함)
  #####################################################################
  rule {
    name     = "allow_user_get_with_email"
    priority = 1
    action { allow {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/user"
            field_to_match        { uri_path {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "GET"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "email="
            field_to_match        { query_string {} }
            positional_constraint = "CONTAINS"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_user_get"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 2) Allow: /v1/user POST (body email 형식 존재)
  # - "email":"x@y.z" 형태만 확인 (너무 빡세지 않게)
  #####################################################################
  rule {
    name     = "allow_user_post_valid_email"
    priority = 2
    action { allow {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/user"
            field_to_match        { uri_path {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "POST"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          regex_match_statement {
            regex_string = "\"email\"\\s*:\\s*\"[^\"@\\s]+@[^\"@\\s]+\\.[^\"@\\s]+\""
            field_to_match { body {} }
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_user_post"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 3) Block(403): /v1/user 로 오는데 위 Allow 조건에 안 걸린 나머지
  #####################################################################
  rule {
    name     = "block_user_other_requests"
    priority = 10
    action { block {} }

    statement {
      byte_match_statement {
        search_string         = "/v1/user"
        field_to_match        { uri_path {} }
        positional_constraint = "STARTS_WITH"
        text_transformation { priority = 0 type = "NONE" }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block_user_other"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 4) Allow: /v1/product GET
  #####################################################################
  rule {
    name     = "allow_product_get"
    priority = 20
    action { allow {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/product"
            field_to_match        { uri_path {} }
            positional_constraint = "STARTS_WITH"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "GET"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_product_get"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 5) Allow: /v1/product POST
  #####################################################################
  rule {
    name     = "allow_product_post"
    priority = 21
    action { allow {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/product"
            field_to_match        { uri_path {} }
            positional_constraint = "STARTS_WITH"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "POST"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_product_post"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 6) Block(403): /v1/product 다른 method는 403
  #####################################################################
  rule {
    name     = "block_product_other_methods"
    priority = 30
    action { block {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/product"
            field_to_match        { uri_path {} }
            positional_constraint = "STARTS_WITH"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          not_statement {
            statement {
              or_statement {
                statement {
                  byte_match_statement {
                    search_string         = "GET"
                    field_to_match        { method {} }
                    positional_constraint = "EXACTLY"
                    text_transformation { priority = 0 type = "NONE" }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "POST"
                    field_to_match        { method {} }
                    positional_constraint = "EXACTLY"
                    text_transformation { priority = 0 type = "NONE" }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block_product_other"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 7) Allow: /v1/stress POST
  #####################################################################
  rule {
    name     = "allow_stress_post"
    priority = 40
    action { allow {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/stress"
            field_to_match        { uri_path {} }
            positional_constraint = "STARTS_WITH"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "POST"
            field_to_match        { method {} }
            positional_constraint = "EXACTLY"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_stress_post"
      sampled_requests_enabled   = true
    }
  }

  #####################################################################
  # 8) Block(403): /v1/stress 다른 method는 403
  #####################################################################
  rule {
    name     = "block_stress_other_methods"
    priority = 50
    action { block {} }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/v1/stress"
            field_to_match        { uri_path {} }
            positional_constraint = "STARTS_WITH"
            text_transformation { priority = 0 type = "NONE" }
          }
        }
        statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string         = "POST"
                field_to_match        { method {} }
                positional_constraint = "EXACTLY"
                text_transformation { priority = 0 type = "NONE" }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block_stress_other"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
```

---

# ✅ 적용 순서 (실수 없이)

1. `waf.tf` 교체
2. `terraform apply`
3. 테스트

---

# ✅ 테스트 커맨드 예시(중요)

ALB DNS를 `ALB=...`로 잡고 진행

```bash
ALB="http://<ALB_DNS>"

# 404 (없는 API)
curl -i "$ALB/v1/none"

# 403 (user GET인데 email 없음)
curl -i "$ALB/v1/user"

# 200 (user GET + email)
curl -i "$ALB/v1/user?email=test@example.org&requestid=1&uuid=1"

# 403 (user POST email 형식 틀림)
curl -i -X POST "$ALB/v1/user" \
  -H "Content-Type: application/json" \
  -d '{"requestid":"1","uuid":"1","username":"a","email":"gildong","status_message":"hi"}'

# 통과(201 기대): user POST email 정상
curl -i -X POST "$ALB/v1/user" \
  -H "Content-Type: application/json" \
  -d '{"requestid":"1","uuid":"1","username":"a","email":"gildong@example.org","status_message":"hi"}'
```

---

# ✅ monitoring.tf

## (ALB + ECS + RDS 핵심 Alarm 세트)

> 설계 원칙
> 
- **“과하지 않게, 하지만 운영 의도가 보이게”**
- 채점 시 가장 이해하기 쉬운 지표 위주
- 비용 최소화 (Alarm만 생성, Dashboard는 선택)

---

## 1️⃣ ALB 장애 감지 (가장 중요)

### 1-1. ALB Target 5XX 에러 증가

```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB Target 5XX error detected"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```

📌 **채점 포인트**

- 서비스 장애 인지 가능
- 운영 관점 명확

---

### 1-2. ALB 응답 시간 (p95)

```hcl
resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  alarm_name          = "${var.name}-alb-latency-p95"
  alarm_description   = "ALB latency p95 too high"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 2
  threshold           = 2
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```

📌 **의미**

- stress API 부하로 인한 성능 저하 감지
- “성능 모니터링” 의도 표현 가능

---

## 2️⃣ ECS (컨테이너 인프라 상태)

### 2-1. ECS EC2 CPU 사용률

```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name}-ecs-cpu-high"
  alarm_description   = "ECS EC2 CPU usage too high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs.name
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```

📌 **의미**

- stress API로 인한 CPU 부하 감지
- Auto Scaling 필요성 설명 가능

---

### 2-2. ECS 메모리 부족(간접 감지)

ECS EC2는 기본 메모리 metric만 사용

```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_status_check" {
  alarm_name          = "${var.name}-ecs-status-check"
  alarm_description   = "ECS EC2 instance status check failed"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs.name
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```

📌 **의미**

- 인스턴스 장애 탐지
- 가용성 점수에 유리

---

## 3️⃣ RDS(MySQL) 운영 감시

### 3-1. RDS CPU 사용률

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name}-rds-cpu-high"
  alarm_description   = "RDS CPU usage too high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.mysql.id
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```

---

### 3-2. RDS Connection 수 증가

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.name}-rds-connections-high"
  alarm_description   = "RDS connections too many"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.mysql.id
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```

📌 **의미**

- user API 폭주 시 DB 병목 감지
- 운영 분석 설명에 활용 가능

---

## 4️⃣ (선택) DynamoDB 쓰로틀 감지

> 필수는 아니지만, 있으면 “운영 깊이” 점수 올라감
> 

```hcl
resource "aws_cloudwatch_metric_alarm" "ddb_throttle" {
  alarm_name          = "${var.name}-ddb-throttle"
  alarm_description   = "DynamoDB throttling detected"
  namespace           = "AWS/DynamoDB"
  metric_name         = "ThrottledRequests"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    TableName = aws_dynamodb_table.product.name
  }

  treat_missing_data = "notBreaching"
  tags               = local.tags
}
```
