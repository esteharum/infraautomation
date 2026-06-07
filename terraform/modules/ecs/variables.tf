variable "aws_account_id"        { type = string }
variable "aws_region"            { type = string }
variable "image_tag"             { type = string }
variable "private_subnet_ids"    { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "tg_fe_arn"             { type = string }
variable "tg_api_arn"            { type = string }
variable "alb_dns_name"          { type = string }
variable "db_host"               { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "sqs_queue_url"   { type = string }
variable "dynamodb_table"  { type = string }
variable "monitoring_alb_dns" {
  type    = string
  default = "localhost"
}
