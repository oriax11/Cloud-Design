output "lb_dns_name" {
  value = aws_lb.main.dns_name
}

output "lb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "listener_http_arn" {
  value = aws_lb_listener.http.arn
}

output "listener_https_arn" {
  value = aws_lb_listener.https.arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.self_signed.arn
}
