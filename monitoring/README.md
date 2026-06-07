# Monitoring — Prometheus Only (3-Hour Edition)

This project uses **Prometheus only** in the monitoring stack.
Grafana, Loki, and Alertmanager are intentionally excluded to fit
the 3-hour competition time limit.

## Why Prometheus Only?

Prometheus running in us-west-2 (Oregon) scraping metrics from ECS
containers in us-east-1 (Virginia) is the key proof that the
Inter-Region VPC Peering connection is fully working.

If Prometheus Targets tab shows ECS tasks as **UP**, it proves:
- VPC Peering pcx-lks-2026 is Active
- Route tables in both regions are correct
- Security Group lks-sg-ecs allows TCP 9100 from 10.1.0.0/16

## Files

```
monitoring/
└── prometheus/
    ├── prometheus.yml     Scrape config — targets ECS private IPs via peering
    └── rules/
        └── alerts.yml     Alert rules for service down detection
```

## Deployment

Prometheus is deployed as a single ECS Fargate service in lks-monitoring-vpc
(us-west-2). Create it manually via the AWS Console — **not Terraform**.

### Steps after ECS application services are running:

1. Get ECS task private IPs from Virginia:
```bash
aws ecs describe-tasks \
  --cluster lks-ecs-cluster \
  --region us-east-1 \
  --tasks $(aws ecs list-tasks \
    --cluster lks-ecs-cluster \
    --region us-east-1 \
    --output text --query 'taskArns[]') \
  --query 'tasks[].attachments[].details[?name==`privateIPv4Address`].value[]' \
  --output text
```

2. Update `prometheus.yml` with the actual IPs (replace 10.0.3.10, 10.0.3.11)

3. Push to GitHub — CI/CD will rebuild the monitoring config image and push to ECR us-west-2

4. Deploy/update the Prometheus ECS service in lks-monitoring-cluster

5. Open Prometheus UI (port 9090) → Status → Targets
   - All targets should show State: UP
   - This confirms inter-region peering is working

## Verification command

```bash
# Check Prometheus targets via AWS CLI (after getting Prometheus task IP)
curl http://<prometheus-private-ip>:9090/api/v1/targets \
  | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

Expected output:
```json
{"job": "lks-api-service",  "health": "up"}
{"job": "lks-fe-service",   "health": "up"}
{"job": "prometheus",        "health": "up"}
```
