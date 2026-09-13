output "file_system_id" {
  value = aws_efs_file_system.main.id
}

output "file_system_arn" {
  value = aws_efs_file_system.main.arn
}

# Both databases now share one file system. The two *_file_system_* outputs
# are kept (with the same value) so the ECS module wiring stays unchanged.
output "inventory_db_file_system_id" {
  value = aws_efs_file_system.main.id
}

output "inventory_db_file_system_arn" {
  value = aws_efs_file_system.main.arn
}

output "billing_db_file_system_id" {
  value = aws_efs_file_system.main.id
}

output "billing_db_file_system_arn" {
  value = aws_efs_file_system.main.arn
}

output "inventory_db_access_point_id" {
  value = aws_efs_access_point.inventory_db.id
}

output "inventory_db_access_point_arn" {
  value = aws_efs_access_point.inventory_db.arn
}

output "billing_db_access_point_id" {
  value = aws_efs_access_point.billing_db.id
}

output "billing_db_access_point_arn" {
  value = aws_efs_access_point.billing_db.arn
}
