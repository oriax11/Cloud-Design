variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "api_gateway_sg_id" {
  type = string
}

variable "inventory_app_sg_id" {
  type = string
}

variable "inventory_db_sg_id" {
  type = string
}

variable "rabbitmq_sg_id" {
  type = string
}

variable "billing_app_sg_id" {
  type = string
}

variable "billing_db_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "lb_dns_name" {
  type = string
}

variable "lb_arn_suffix" {
  type = string
}

variable "inventory_db_file_system_id" {
  type = string
}

variable "inventory_db_file_system_arn" {
  type = string
}

variable "inventory_db_access_point_id" {
  type = string
}

variable "inventory_db_access_point_arn" {
  type = string
}

variable "billing_db_file_system_id" {
  type = string
}

variable "billing_db_file_system_arn" {
  type = string
}

variable "billing_db_access_point_id" {
  type = string
}

variable "billing_db_access_point_arn" {
  type = string
}

# --- Application secrets (injected by the root module from terraform.tfvars) ---

variable "inventory_db_user" {
  type      = string
  sensitive = true
}

variable "inventory_db_password" {
  type      = string
  sensitive = true
}

variable "inventory_db_name" {
  type      = string
  sensitive = true
}

variable "billing_db_user" {
  type      = string
  sensitive = true
}

variable "billing_db_password" {
  type      = string
  sensitive = true
}

variable "billing_db_name" {
  type      = string
  sensitive = true
}

variable "rabbitmq_user" {
  type      = string
  sensitive = true
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}

variable "rabbitmq_queue" {
  type      = string
  sensitive = true
}
