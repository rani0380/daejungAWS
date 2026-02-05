resource "aws_dynamodb_table" "product" {
  name           = "${local.name_prefix}-product"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Name = "${local.name_prefix}-product"
  }
}