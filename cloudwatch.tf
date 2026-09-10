resource "aws_cloudwatch_log_group" "inventory" {
  name              = "/ecs/cloud-design-inventory"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "billing" {
  name              = "/ecs/cloud-design-billing"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/cloud-design-api-gateway"
  retention_in_days = 7
}