resource "aws_secretsmanager_secret" "db_password" {
  name = "db_password"
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({ username = "admin", password = "StrongPass123" })
}
