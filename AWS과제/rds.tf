resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.app_db.id]
}

resource "aws_db_instance" "mysql" {
  identifier              = "green-red-db"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  username                = "admin"
  password                = "StrongPass123"
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
}
