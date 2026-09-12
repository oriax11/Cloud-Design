output "alb_dns_name" {
  value = module.alb.lb_dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "app_url" {
  value = "http://${module.alb.lb_dns_name}"
}

output "app_url_https" {
  value = "https://${module.alb.lb_dns_name}"
}

output "acm_certificate_arn" {
  value = module.alb.acm_certificate_arn
}
