# ── ECS Cluster & Services (us-east-1) ──────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  lab_role_arn = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  fe_image     = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/lks-fe-app:${var.image_tag}"
  api_image    = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/lks-api-app:${var.image_tag}"
}

# ── ECS Cluster ──────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = "lks-ecs-cluster"
  tags = { Name = "lks-ecs-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}


resource "aws_cloudwatch_log_group" "fe" {
  name              = "/ecs/lks-fe-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/lks-api-service"
  retention_in_days = 7
}


resource "aws_ecs_task_definition" "fe" {
  family                   = "lks-fe-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = local.lab_role_arn
  task_role_arn            = local.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "lks-fe-app"
      image     = local.fe_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "PORT",           value = "3000" },
        { name = "API_URL",        value = "http://${var.alb_dns_name}" },
        { name = "GRAFANA_URL",    value = "http://${var.monitoring_alb_dns}:80" },
        { name = "PROMETHEUS_URL", value = "http://${var.monitoring_alb_dns}:8080" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/lks-fe-service"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "lks-fe-task" }
}


resource "aws_ecs_task_definition" "api" {
  family                   = "lks-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = local.lab_role_arn
  task_role_arn            = local.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "lks-api-app"
      image     = local.api_image
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        },
        {
          containerPort = 9100
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_HOST",          value = var.db_host },
        { name = "DB_PASSWORD",      value = var.db_password },
        { name = "DB_NAME",          value = "lksdb" },
        { name = "DB_USER",          value = "lksadmin" },
        { name = "DB_SSL",           value = "false" },
        { name = "PYTHONUNBUFFERED", value = "1" },
        { name = "SQS_URL",          value = var.sqs_queue_url },
        { name = "DYNAMO_TABLE",     value = var.dynamodb_table }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/lks-api-service"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "lks-api-task" }
}


resource "aws_ecs_service" "fe" {
  name                              = "lks-fe-service"
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.fe.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.tg_fe_arn
    container_name   = "lks-fe-app"
    container_port   = 3000
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = { Name = "lks-fe-service" }
}


resource "aws_ecs_service" "api" {
  name                              = "lks-api-service"
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.tg_api_arn
    container_name   = "lks-api-app"
    container_port   = 8080
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = { Name = "lks-api-service" }
}


resource "aws_appautoscaling_target" "fe" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.fe.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


resource "aws_appautoscaling_target" "api" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
