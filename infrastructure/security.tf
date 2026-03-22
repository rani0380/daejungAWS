# 보안 그룹 - ALB
resource "aws_security_group" "alb" {
  name_prefix = "worldpay-alb-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "worldpay-alb-sg"
  }
}

# 보안 그룹 - ECS
resource "aws_security_group" "ecs" {
  name_prefix = "worldpay-ecs-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "worldpay-ecs-sg"
  }
}

# 보안 그룹 - RDS
resource "aws_security_group" "rds" {
  name_prefix = "worldpay-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "worldpay-rds-sg"
  }
}

# RDS 서브넷 그룹
resource "aws_db_subnet_group" "main" {
  name       = "worldpay-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "worldpay-db-subnet-group"
  }
}

# RDS 인스턴스 (PostgreSQL)
resource "aws_db_instance" "main" {
  identifier = "worldpay-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = "worldpay"
  username = "admin"
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  multi_az               = true
  publicly_accessible    = false
  deletion_protection    = true

  tags = {
    Name = "worldpay-database"
  }
}