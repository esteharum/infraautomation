# Module: security

Creates all four Security Groups used in the architecture.

## Security Groups to create

### lks-sg-alb
Attached to the Application Load Balancer.
- Inbound: TCP 80 from 0.0.0.0/0
- Inbound: TCP 443 from 0.0.0.0/0
- Outbound: all traffic

### lks-sg-ecs
Attached to all ECS Fargate tasks in lks-vpc.
- Inbound: TCP 3000 from lks-sg-alb (Frontend)
- Inbound: TCP 8080 from lks-sg-alb (API)
- Inbound: TCP 5000 from lks-sg-alb (Analytics)
- Inbound: TCP 9100 from 10.1.0.0/16 (Prometheus scraping via VPC Peering)
- Outbound: all traffic (needed for ECR pull, SSM, CloudWatch)

### lks-sg-db
Attached to RDS instance.
- Inbound: TCP 5432 from lks-sg-ecs
- Inbound: TCP 443 from lks-sg-ecs (DynamoDB/SQS HTTPS)
- Outbound: none

### lks-sg-monitoring
Attached to all monitoring ECS tasks in lks-monitoring-vpc.
- Inbound: TCP 9090 from lks-sg-monitoring (Prometheus internal)
- Inbound: TCP 3000 from 10.0.0.0/16 (Grafana access from app VPC)
- Inbound: TCP 3100 from lks-sg-monitoring (Loki internal)
- Inbound: TCP 9093 from lks-sg-monitoring (Alertmanager internal)
- Outbound: all traffic (scraping targets in lks-vpc via peering)

## Required inputs

| Variable | Type |
|---|---|
| `vpc_id` | string |
| `monitoring_vpc_cidr` | string |

## Required outputs

| Output |
|---|
| `sg_alb_id` |
| `sg_ecs_id` |
| `sg_db_id` |
| `sg_monitoring_id` |
