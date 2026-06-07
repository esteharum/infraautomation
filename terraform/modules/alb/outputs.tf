output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "tg_fe_arn" {
  value = aws_lb_target_group.fe.arn
}

output "tg_api_arn" {
  value = aws_lb_target_group.api.arn
}
