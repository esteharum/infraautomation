# Module: alb

Creates the Application Load Balancer, three Target Groups, and Listener Rules.

## Resources to create

- `aws_lb` — lks-alb
  - internal: false (internet-facing)
  - subnets:  both public subnets
  - security_groups: [lks-sg-alb]

- `aws_lb_target_group` × 3

  | Name | Port | Health Check Path |
  |---|---|---|
  | lks-tg-fe | 3000 | /health |
  | lks-tg-api | 8080 | /api/health |
  | lks-tg-analytics | 5000 | /api/stats/health |

  All three: target_type=ip, protocol=HTTP, healthy_threshold=2,
  unhealthy_threshold=3, interval=30

- `aws_lb_listener` — HTTP:80
  - default_action: forward to lks-tg-fe

- `aws_lb_listener_rule` × 2 (the default rule covers FE)
  - Priority 1: path /api/stats/* → forward to lks-tg-analytics
  - Priority 2: path /api/*      → forward to lks-tg-api

## Required inputs

| Variable | Description |
|---|---|
| `alb_name` | "lks-alb" |
| `public_subnet_ids` | From vpc module |
| `security_group_id` | lks-sg-alb |
| `vpc_id` | For target group association |

## Required outputs

| Output |
|---|
| `alb_dns_name` |
| `alb_zone_id` |
| `tg_fe_arn` |
| `tg_api_arn` |
| `tg_analytics_arn` |
