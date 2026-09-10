# =====================================================
# ALB SECURITY GROUP
# Internet -> ALB
# =====================================================

resource "aws_security_group" "alb" {
  name        = "cloud-design-alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-alb-sg"
  }
}


# =====================================================
# API GATEWAY SECURITY GROUP
# ALB -> API Gateway
#
# API Gateway -> Inventory App
# API Gateway -> RabbitMQ
# =====================================================

resource "aws_security_group" "api_gateway" {
  name        = "cloud-design-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = aws_vpc.main.id

  # Only ALB can access API Gateway
  ingress {
    description     = "Traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-api-gateway-sg"
  }
}


# =====================================================
# INVENTORY APP SECURITY GROUP
#
# API Gateway -> Inventory App
# Inventory App -> Inventory DB
# =====================================================

resource "aws_security_group" "inventory_app" {
  name        = "cloud-design-inventory-app-sg"
  description = "Security group for Inventory App"
  vpc_id      = aws_vpc.main.id

  # Only API Gateway can access Inventory App
  ingress {
    description     = "Traffic from API Gateway"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-inventory-app-sg"
  }
}


# =====================================================
# INVENTORY DATABASE SECURITY GROUP
#
# Inventory App -> Inventory DB
# =====================================================

resource "aws_security_group" "inventory_db" {
  name        = "cloud-design-inventory-db-sg"
  description = "Security group for Inventory PostgreSQL"
  vpc_id      = aws_vpc.main.id

  # ONLY Inventory App can access PostgreSQL
  ingress {
    description     = "PostgreSQL from Inventory App"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.inventory_app.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-inventory-db-sg"
  }
}


# =====================================================
# RABBITMQ SECURITY GROUP
#
# API Gateway -> RabbitMQ
# =====================================================

resource "aws_security_group" "rabbitmq" {
  name        = "cloud-design-rabbitmq-sg"
  description = "Security group for RabbitMQ"
  vpc_id      = aws_vpc.main.id

  # Only API Gateway can access RabbitMQ
  ingress {
    description     = "RabbitMQ from API Gateway"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-rabbitmq-sg"
  }
}


# =====================================================
# BILLING APP SECURITY GROUP
#
# RabbitMQ -> Billing App
# Billing App -> Billing DB
# =====================================================

resource "aws_security_group" "billing_app" {
  name        = "cloud-design-billing-app-sg"
  description = "Security group for Billing App"
  vpc_id      = aws_vpc.main.id

  # RabbitMQ can access Billing App
  ingress {
    description     = "Traffic from RabbitMQ"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.rabbitmq.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-billing-app-sg"
  }
}


# =====================================================
# BILLING DATABASE SECURITY GROUP
#
# Billing App -> Billing DB
# =====================================================

resource "aws_security_group" "billing_db" {
  name        = "cloud-design-billing-db-sg"
  description = "Security group for Billing PostgreSQL"
  vpc_id      = aws_vpc.main.id

  # ONLY Billing App can access PostgreSQL
  ingress {
    description     = "PostgreSQL from Billing App"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.billing_app.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-billing-db-sg"
  }
}