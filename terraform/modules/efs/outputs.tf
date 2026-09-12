output "inventory_db_file_system_id" {
  value = aws_efs_file_system.inventory_db.id
}

output "inventory_db_file_system_arn" {
  value = aws_efs_file_system.inventory_db.arn
}

output "inventory_db_access_point_id" {
  value = aws_efs_access_point.inventory_db.id
}

output "inventory_db_access_point_arn" {
  value = aws_efs_access_point.inventory_db.arn
}

output "billing_db_file_system_id" {
  value = aws_efs_file_system.billing_db.id
}

output "billing_db_file_system_arn" {
  value = aws_efs_file_system.billing_db.arn
}

output "billing_db_access_point_id" {
  value = aws_efs_access_point.billing_db.id
}

output "billing_db_access_point_arn" {
  value = aws_efs_access_point.billing_db.arn
}
