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
resource "aws_cloudwatch_log_group" "inventory_db" {
  name              = "/ecs/cloud-design-inventory-db"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "billing_db" {
  name              = "/ecs/cloud-design-billing-db"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/ecs/cloud-design-rabbitmq"
  retention_in_days = 7
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "cloud-design"

  dashboard_body = jsonencode({
    widgets = [

      # =====================================================
      # API GATEWAY CPU
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "API Gateway CPU"

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.api-gateway.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # API GATEWAY MEMORY
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "API Gateway Memory"

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.api-gateway.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # INVENTORY CPU
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "Inventory CPU"

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.inventory_app.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # INVENTORY MEMORY
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "Inventory Memory"

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.inventory_app.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # BILLING CPU
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "Billing CPU"

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.billing_app.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # BILLING MEMORY
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "Billing Memory"

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.billing_app.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # ALB REQUEST COUNT
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "ALB Requests"

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              var.lb_arn_suffix
            ]
          ]

          period = 300
          stat   = "Sum"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # ALB TARGET RESPONSE TIME
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "ALB Target Response Time (s)"

          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              var.lb_arn_suffix
            ]
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # ALB 5XX
      # =====================================================
      {
        type   = "metric"
        width  = 6
        height = 4

        properties = {
          title = "ALB 5XX Responses"

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer",
              var.lb_arn_suffix
            ]
          ]

          period = 300
          stat   = "Sum"
          region = "us-east-1"

          view = "singleValue"

          singleValueFullPrecision = false
        }
      },

      # =====================================================
      # RUNNING TASKS PER SERVICE
      # =====================================================
      {
        type   = "metric"
        width  = 12
        height = 4

        properties = {
          title = "ECS Running Tasks"

          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.api-gateway.name],
            ["...", aws_ecs_service.inventory_app.name],
            ["...", aws_ecs_service.billing_app.name],
          ]

          period = 300
          stat   = "Average"
          region = "us-east-1"
        }
      },

    ]
  })
}
