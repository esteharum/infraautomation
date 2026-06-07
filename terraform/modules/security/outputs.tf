output "sg_alb_id" {
  value = aws_security_group.alb.id
}

output "sg_ecs_id" {
  value = aws_security_group.ecs.id
}

output "sg_db_id" {
  value = aws_security_group.db.id
}

output "sg_monitoring_id" {
  value = aws_security_group.monitoring.id
}
