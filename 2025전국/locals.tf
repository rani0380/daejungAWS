locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  
  services = ["user", "product", "stress"]
  
  ports = {
    http  = 80
    https = 443
    app   = 3000
    mysql = 3306
  }
}