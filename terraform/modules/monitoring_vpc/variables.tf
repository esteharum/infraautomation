variable "aws_account_id"      { type = string }
variable "monitoring_vpc_cidr" { type = string }
variable "private_subnet_cidrs" { type = list(string) }
variable "public_subnet_cidrs"  { type = list(string) }
variable "availability_zones"   { type = list(string) }
variable "virginia_api_cidr"    { type = string }
variable "image_tag" {
  type    = string
  default = "latest"
}
