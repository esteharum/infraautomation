output "monitoring_vpc_id" {
  value = aws_vpc.monitoring.id
}

output "monitoring_private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "monitoring_public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "monitoring_private_route_table_id" {
  value = aws_route_table.private.id
}

output "monitoring_alb_dns_name" {
  value = aws_lb.monitoring.dns_name
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}
