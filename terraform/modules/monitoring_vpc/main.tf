
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.oregon]
    }
  }
}

locals {
  lab_role_arn      = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  prom_image        = "${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com/lks-monitoring:${var.image_tag}"
  grafana_image     = "${var.aws_account_id}.dkr.ecr.us-west-2.amazonaws.com/lks-monitoring:grafana"
  az_suffixes       = [for az in var.availability_zones : substr(az, -2, -1)]
}


resource "aws_vpc" "monitoring" {
  provider             = aws.oregon
  cidr_block           = var.monitoring_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "lks-monitoring-vpc" }
}


resource "aws_subnet" "private" {
  provider          = aws.oregon
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.monitoring.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "lks-monitoring-private-${local.az_suffixes[count.index]}" }
}


resource "aws_subnet" "public" {
  provider                = aws.oregon
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "lks-monitoring-public-${local.az_suffixes[count.index]}" }
}


resource "aws_internet_gateway" "monitoring" {
  provider = aws.oregon
  vpc_id   = aws_vpc.monitoring.id
  tags     = { Name = "lks-monitoring-igw" }
}


resource "aws_route_table" "public" {
  provider = aws.oregon
  vpc_id   = aws_vpc.monitoring.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring.id
  }
  tags = { Name = "lks-monitoring-public-rt" }
}

resource "aws_route_table" "private" {
  provider = aws.oregon
  vpc_id   = aws_vpc.monitoring.id
  tags     = { Name = "lks-monitoring-rt" }
}

resource "aws_route_table_association" "public" {
  provider       = aws.oregon
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  provider       = aws.oregon
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


resource "aws_security_group" "endpoints" {
  provider    = aws.oregon
  name        = "lks-sg-endpoints-oregon"
  description = "Allow HTTPS from within VPC for VPC Endpoints"
  vpc_id      = aws_vpc.monitoring.id
  tags        = { Name = "lks-sg-endpoints-oregon" }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_monitoring" {
  provider    = aws.oregon
  name        = "lks-sg-ecs-monitoring"
  description = "ECS monitoring tasks - Prometheus and Grafana"
  vpc_id      = aws_vpc.monitoring.id
  tags        = { Name = "lks-sg-ecs-monitoring" }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_vpc_cidr]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "alb_monitoring" {
  provider    = aws.oregon
  name        = "lks-sg-alb-monitoring"
  description = "Monitoring ALB - public access for Grafana and Prometheus"
  vpc_id      = aws_vpc.monitoring.id
  tags        = { Name = "lks-sg-alb-monitoring" }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "bastion" {
  provider    = aws.oregon
  name        = "lks-sg-bastion-oregon"
  description = "Bastion host - SSM only, no inbound SSH"
  vpc_id      = aws_vpc.monitoring.id
  tags        = { Name = "lks-sg-bastion-oregon" }

  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_vpc_endpoint" "ssm" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ssm" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ssmmessages" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ec2messages" }
}

resource "aws_vpc_endpoint" "logs" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-logs" }
}

resource "aws_vpc_endpoint" "ecr_api" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ecr-api" }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ecr-dkr" }
}

resource "aws_vpc_endpoint" "ecs" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ecs" }
}

resource "aws_vpc_endpoint" "ecs_agent" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ecs-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ecs-agent" }
}

resource "aws_vpc_endpoint" "ecs_telemetry" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-ecs-telemetry" }
}

resource "aws_vpc_endpoint" "monitoring" {
  provider            = aws.oregon
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.us-west-2.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "lks-endpoint-monitoring" }
}


resource "aws_vpc_endpoint" "s3" {
  provider          = aws.oregon
  vpc_id            = aws_vpc.monitoring.id
  service_name      = "com.amazonaws.us-west-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "lks-endpoint-s3" }
}


resource "aws_ecs_cluster" "monitoring" {
  provider = aws.oregon
  name     = "lks-monitoring-cluster"
  tags     = { Name = "lks-monitoring-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "monitoring" {
  provider           = aws.oregon
  cluster_name       = aws_ecs_cluster.monitoring.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}


resource "aws_cloudwatch_log_group" "prometheus" {
  provider          = aws.oregon
  name              = "/ecs/lks-prometheus-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "grafana" {
  provider          = aws.oregon
  name              = "/ecs/lks-grafana-service"
  retention_in_days = 7
}


resource "aws_lb" "monitoring" {
  provider           = aws.oregon
  name               = "lks-monitoring-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_monitoring.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = "lks-monitoring-alb" }
}

resource "aws_lb_target_group" "grafana" {
  provider    = aws.oregon
  name        = "lks-tg-grafana"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.monitoring.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
  tags = { Name = "lks-tg-grafana" }
}

resource "aws_lb_target_group" "prometheus" {
  provider    = aws.oregon
  name        = "lks-tg-prometheus"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = aws_vpc.monitoring.id
  target_type = "ip"

  health_check {
    path                = "/-/healthy"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
  tags = { Name = "lks-tg-prometheus" }
}

resource "aws_lb_listener" "grafana" {
  provider          = aws.oregon
  load_balancer_arn = aws_lb.monitoring.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

# Listener :8080 → Prometheus (port 9090)
resource "aws_lb_listener" "prometheus" {
  provider          = aws.oregon
  load_balancer_arn = aws_lb.monitoring.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}


resource "aws_ecs_task_definition" "prometheus" {
  provider                 = aws.oregon
  family                   = "lks-prometheus-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = local.lab_role_arn
  task_role_arn            = local.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "lks-prometheus"
      image     = local.prom_image
      essential = true
      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "SCRAPE_TARGET", value = "${var.virginia_api_cidr}:9100" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/lks-prometheus-service"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "lks-prometheus-task" }
}


resource "aws_ecs_task_definition" "grafana" {
  provider                 = aws.oregon
  family                   = "lks-grafana-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = local.lab_role_arn
  task_role_arn            = local.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "lks-grafana"
      image     = local.grafana_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = "admin" },
        { name = "GF_SERVER_HTTP_PORT",        value = "3000" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/lks-grafana-service"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "lks-grafana-task" }
}


resource "aws_ecs_service" "prometheus" {
  provider                          = aws.oregon
  name                              = "lks-prometheus-service"
  cluster                           = aws_ecs_cluster.monitoring.id
  task_definition                   = aws_ecs_task_definition.prometheus.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_monitoring.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "lks-prometheus"
    container_port   = 9090
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = { Name = "lks-prometheus-service" }
}


resource "aws_ecs_service" "grafana" {
  provider                          = aws.oregon
  name                              = "lks-grafana-service"
  cluster                           = aws_ecs_cluster.monitoring.id
  task_definition                   = aws_ecs_task_definition.grafana.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_monitoring.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "lks-grafana"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = { Name = "lks-grafana-service" }
}


data "aws_ami" "al2023" {
  provider    = aws.oregon
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_instance_profile" "bastion" {
  provider = aws.oregon
  name     = "lks-bastion-oregon-profile"
  role     = "LabRole"
}

resource "aws_instance" "bastion" {
  provider               = aws.oregon
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  
  associate_public_ip_address = false

  user_data = base64encode(<<-EOF
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
  )

  tags = {
    Name = "lks-bastion-oregon"
  }
}
