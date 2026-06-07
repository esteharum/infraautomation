
provider "aws" {
  alias  = "oregon"
  region = "us-west-2"
}

module "ecr" {
  source = "./modules/ecr"

  aws_account_id = var.aws_account_id

  providers = {
    aws        = aws
    aws.oregon = aws.oregon
  }
}


module "monitoring_vpc" {
  source = "./modules/monitoring_vpc"

  aws_account_id       = var.aws_account_id
  monitoring_vpc_cidr  = var.monitoring_vpc_cidr
  private_subnet_cidrs = var.monitoring_private_subnet_cidrs
  public_subnet_cidrs  = var.monitoring_public_subnet_cidrs
  availability_zones   = var.monitoring_availability_zones
  virginia_api_cidr    = var.private_subnet_cidrs[0]  # 10.0.3.0/24
  image_tag            = var.image_tag

  providers = {
    aws.oregon = aws.oregon
  }
}


module "vpc_peering" {
  source = "./modules/vpc_peering"

  virginia_vpc_id                = module.vpc.vpc_id
  virginia_vpc_cidr              = var.vpc_cidr
  virginia_private_route_table_id = module.vpc.private_route_table_id
  oregon_vpc_id                  = module.monitoring_vpc.monitoring_vpc_id
  oregon_vpc_cidr                = var.monitoring_vpc_cidr
  oregon_private_route_table_id  = module.monitoring_vpc.monitoring_private_route_table_id

  providers = {
    aws.virginia = aws
    aws.oregon   = aws.oregon
  }

  depends_on = [module.vpc, module.monitoring_vpc]
}

module "ecs" {
  source = "./modules/ecs"

  aws_account_id        = var.aws_account_id
  aws_region            = var.aws_region
  image_tag             = var.image_tag
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security.sg_ecs_id
  tg_fe_arn             = module.alb.tg_fe_arn
  tg_api_arn            = module.alb.tg_api_arn
  alb_dns_name          = module.alb.alb_dns_name
  db_host               = module.database.rds_endpoint
  db_password           = var.db_password
  sqs_queue_url         = module.database.sqs_queue_url
  dynamodb_table        = module.database.dynamodb_table_name
  # BUG FIX: monitoring_alb_dns sekarang di-pass dari module monitoring_vpc
  monitoring_alb_dns    = module.monitoring_vpc.monitoring_alb_dns_name
}
