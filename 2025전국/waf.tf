# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name  = "${local.name_prefix}-waf"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  # Email validation rule for user service
  rule {
    name     = "EmailValidationRule"
    priority = 10
    
    action {
      block {}
    }
    
    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string = "/v1/user"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }
        statement {
          not_statement {
            statement {
              regex_pattern_set_reference_statement {
                arn = aws_wafv2_regex_pattern_set.email.arn
                field_to_match {
                  body {}
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "EmailValidationRule"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }
  
  tags = {
    Name = "${local.name_prefix}-waf"
  }
}

# Email regex pattern
resource "aws_wafv2_regex_pattern_set" "email" {
  name  = "${local.name_prefix}-email-pattern"
  scope = "REGIONAL"
  
  regular_expression {
    regex_string = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
  }
  
  tags = {
    Name = "${local.name_prefix}-email-pattern"
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}