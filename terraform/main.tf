# =====================================================
# ROOT MODULE — wires the child modules together and
# migrates the previously flat resources into them via
# `moved` blocks (no resources are recreated).
# =====================================================

module "vpc" {
  source = "./modules/vpc"
}

module "security" {
  source = "./modules/security"

  vpc_id = module.vpc.vpc_id
}

module "efs" {
  source = "./modules/efs"

  vpc_id = module.vpc.vpc_id

  private_subnet_a_id = module.vpc.private_subnet_a_id
  private_subnet_b_id = module.vpc.private_subnet_b_id

  inventory_db_sg_id = module.security.inventory_db_sg_id
  billing_db_sg_id   = module.security.billing_db_sg_id
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}

module "ecs" {
  source = "./modules/ecs"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  api_gateway_sg_id   = module.security.api_gateway_sg_id
  inventory_app_sg_id = module.security.inventory_app_sg_id
  inventory_db_sg_id  = module.security.inventory_db_sg_id
  rabbitmq_sg_id      = module.security.rabbitmq_sg_id
  billing_app_sg_id   = module.security.billing_app_sg_id
  billing_db_sg_id    = module.security.billing_db_sg_id

  target_group_arn = module.alb.target_group_arn
  lb_dns_name      = module.alb.lb_dns_name
  lb_arn_suffix    = module.alb.lb_arn_suffix

  inventory_db_file_system_id   = module.efs.inventory_db_file_system_id
  inventory_db_file_system_arn  = module.efs.inventory_db_file_system_arn
  inventory_db_access_point_id  = module.efs.inventory_db_access_point_id
  inventory_db_access_point_arn = module.efs.inventory_db_access_point_arn
  billing_db_file_system_id     = module.efs.billing_db_file_system_id
  billing_db_file_system_arn    = module.efs.billing_db_file_system_arn
  billing_db_access_point_id    = module.efs.billing_db_access_point_id
  billing_db_access_point_arn   = module.efs.billing_db_access_point_arn

  inventory_db_user     = var.inventory_db_user
  inventory_db_password = var.inventory_db_password
  inventory_db_name     = var.inventory_db_name
  billing_db_user       = var.billing_db_user
  billing_db_password   = var.billing_db_password
  billing_db_name       = var.billing_db_name
  rabbitmq_user         = var.rabbitmq_user
  rabbitmq_password     = var.rabbitmq_password
  rabbitmq_queue        = var.rabbitmq_queue
}

# ---------------------------------------------------------------------------
# State migrations: root -> module.<name> (no infrastructure changes)
# ---------------------------------------------------------------------------

# vpc
moved {
  from = aws_vpc.main
  to   = module.vpc.aws_vpc.main
}

moved {
  from = aws_internet_gateway.main
  to   = module.vpc.aws_internet_gateway.main
}

moved {
  from = aws_subnet.public_a
  to   = module.vpc.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.vpc.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.vpc.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_b
  to   = module.vpc.aws_subnet.private_b
}

moved {
  from = aws_route_table.public
  to   = module.vpc.aws_route_table.public
}

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private
}

moved {
  from = aws_route_table_association.public_a
  to   = module.vpc.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.vpc.aws_route_table_association.public_b
}

moved {
  from = aws_route_table_association.private_a
  to   = module.vpc.aws_route_table_association.private_a
}

moved {
  from = aws_route_table_association.private_b
  to   = module.vpc.aws_route_table_association.private_b
}

moved {
  from = aws_eip.nat
  to   = module.vpc.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.vpc.aws_nat_gateway.main
}

# security
moved {
  from = aws_security_group.alb
  to   = module.security.aws_security_group.alb
}

moved {
  from = aws_security_group.api_gateway
  to   = module.security.aws_security_group.api_gateway
}

moved {
  from = aws_security_group.inventory_app
  to   = module.security.aws_security_group.inventory_app
}

moved {
  from = aws_security_group.inventory_db
  to   = module.security.aws_security_group.inventory_db
}

moved {
  from = aws_security_group.rabbitmq
  to   = module.security.aws_security_group.rabbitmq
}

moved {
  from = aws_security_group.billing_app
  to   = module.security.aws_security_group.billing_app
}

moved {
  from = aws_security_group.billing_db
  to   = module.security.aws_security_group.billing_db
}

# efs
moved {
  from = aws_efs_file_system.inventory_db
  to   = module.efs.aws_efs_file_system.inventory_db
}

moved {
  from = aws_efs_file_system.billing_db
  to   = module.efs.aws_efs_file_system.billing_db
}

moved {
  from = aws_efs_mount_target.inventory_db_a
  to   = module.efs.aws_efs_mount_target.inventory_db_a
}

moved {
  from = aws_efs_mount_target.inventory_db_b
  to   = module.efs.aws_efs_mount_target.inventory_db_b
}

moved {
  from = aws_efs_mount_target.billing_db_a
  to   = module.efs.aws_efs_mount_target.billing_db_a
}

moved {
  from = aws_efs_mount_target.billing_db_b
  to   = module.efs.aws_efs_mount_target.billing_db_b
}

moved {
  from = aws_efs_access_point.inventory_db
  to   = module.efs.aws_efs_access_point.inventory_db
}

moved {
  from = aws_efs_access_point.billing_db
  to   = module.efs.aws_efs_access_point.billing_db
}

moved {
  from = aws_security_group.inventory_db_efs
  to   = module.efs.aws_security_group.inventory_db_efs
}

moved {
  from = aws_security_group.billing_db_efs
  to   = module.efs.aws_security_group.billing_db_efs
}

# alb
moved {
  from = tls_private_key.acm
  to   = module.alb.tls_private_key.acm
}

moved {
  from = tls_self_signed_cert.acm
  to   = module.alb.tls_self_signed_cert.acm
}

moved {
  from = aws_acm_certificate.self_signed
  to   = module.alb.aws_acm_certificate.self_signed
}

moved {
  from = aws_lb.main
  to   = module.alb.aws_lb.main
}

moved {
  from = aws_lb_target_group.app
  to   = module.alb.aws_lb_target_group.app
}

moved {
  from = aws_lb_listener.http
  to   = module.alb.aws_lb_listener.http
}

moved {
  from = aws_lb_listener.https
  to   = module.alb.aws_lb_listener.https
}

# ecs
moved {
  from = data.aws_iam_policy_document.ecs_assume_role
  to   = module.ecs.data.aws_iam_policy_document.ecs_assume_role
}

moved {
  from = aws_iam_role.ecs_execution
  to   = module.ecs.aws_iam_role.ecs_execution
}

moved {
  from = aws_iam_role_policy_attachment.ecs_execution
  to   = module.ecs.aws_iam_role_policy_attachment.ecs_execution
}

moved {
  from = aws_iam_role.ecs_task
  to   = module.ecs.aws_iam_role.ecs_task
}

moved {
  from = aws_iam_role_policy.ecs_execution_secrets
  to   = module.ecs.aws_iam_role_policy.ecs_execution_secrets
}

moved {
  from = aws_iam_role_policy.ecs_exec
  to   = module.ecs.aws_iam_role_policy.ecs_exec
}

moved {
  from = aws_iam_policy.efs_access
  to   = module.ecs.aws_iam_policy.efs_access
}

moved {
  from = aws_iam_role_policy_attachment.ecs_task_efs_access
  to   = module.ecs.aws_iam_role_policy_attachment.ecs_task_efs_access
}

moved {
  from = aws_secretsmanager_secret.app
  to   = module.ecs.aws_secretsmanager_secret.app
}

moved {
  from = aws_secretsmanager_secret_version.app
  to   = module.ecs.aws_secretsmanager_secret_version.app
}

moved {
  from = aws_ecs_cluster.main
  to   = module.ecs.aws_ecs_cluster.main
}

moved {
  from = aws_service_discovery_private_dns_namespace.main
  to   = module.ecs.aws_service_discovery_private_dns_namespace.main
}

moved {
  from = aws_ecs_task_definition.api-gateway
  to   = module.ecs.aws_ecs_task_definition.api-gateway
}

moved {
  from = aws_ecs_task_definition.inventory
  to   = module.ecs.aws_ecs_task_definition.inventory
}

moved {
  from = aws_ecs_task_definition.billing
  to   = module.ecs.aws_ecs_task_definition.billing
}

moved {
  from = aws_ecs_task_definition.rabbit_queue
  to   = module.ecs.aws_ecs_task_definition.rabbit_queue
}

moved {
  from = aws_ecs_task_definition.inventory_db
  to   = module.ecs.aws_ecs_task_definition.inventory_db
}

moved {
  from = aws_ecs_task_definition.billing_db
  to   = module.ecs.aws_ecs_task_definition.billing_db
}

moved {
  from = aws_ecs_service.api-gateway
  to   = module.ecs.aws_ecs_service.api-gateway
}

moved {
  from = aws_ecs_service.inventory_app
  to   = module.ecs.aws_ecs_service.inventory_app
}

moved {
  from = aws_ecs_service.billing_app
  to   = module.ecs.aws_ecs_service.billing_app
}

moved {
  from = aws_ecs_service.rabbit_queue
  to   = module.ecs.aws_ecs_service.rabbit_queue
}

moved {
  from = aws_ecs_service.inventory_db
  to   = module.ecs.aws_ecs_service.inventory_db
}

moved {
  from = aws_ecs_service.billing_db
  to   = module.ecs.aws_ecs_service.billing_db
}

moved {
  from = aws_appautoscaling_target.app
  to   = module.ecs.aws_appautoscaling_target.app
}

moved {
  from = aws_appautoscaling_policy.app_cpu
  to   = module.ecs.aws_appautoscaling_policy.app_cpu
}

moved {
  from = aws_cognito_user_pool.main
  to   = module.ecs.aws_cognito_user_pool.main
}

moved {
  from = aws_cognito_user_pool_client.app
  to   = module.ecs.aws_cognito_user_pool_client.app
}

moved {
  from = aws_cloudwatch_log_group.inventory
  to   = module.ecs.aws_cloudwatch_log_group.inventory
}

moved {
  from = aws_cloudwatch_log_group.billing
  to   = module.ecs.aws_cloudwatch_log_group.billing
}

moved {
  from = aws_cloudwatch_log_group.api_gateway
  to   = module.ecs.aws_cloudwatch_log_group.api_gateway
}

moved {
  from = aws_cloudwatch_log_group.inventory_db
  to   = module.ecs.aws_cloudwatch_log_group.inventory_db
}

moved {
  from = aws_cloudwatch_log_group.billing_db
  to   = module.ecs.aws_cloudwatch_log_group.billing_db
}

moved {
  from = aws_cloudwatch_log_group.rabbitmq
  to   = module.ecs.aws_cloudwatch_log_group.rabbitmq
}

moved {
  from = aws_cloudwatch_dashboard.main
  to   = module.ecs.aws_cloudwatch_dashboard.main
}
