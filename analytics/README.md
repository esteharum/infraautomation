# Analytics Service — Python FastAPI

Provides aggregate statistics and system health metrics for LKS 2026.  
Queries both PostgreSQL (user counts) and Prometheus (ECS metrics via VPC Peering).  
Also exposes a `/metrics` endpoint so Prometheus can scrape this service itself.

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/stats/health` | Health check |
| GET | `/api/stats/summary` | Live metrics — polled by MetricsBar in frontend |
| GET | `/api/stats/users` | User growth breakdown (total, last 7 days, last 30 days) |
| GET | `/metrics` | Prometheus scrape endpoint (prometheus-client format) |

## Summary response

`GET /api/stats/summary` returns:

```json
{
  "total_users":     42,
  "ecs_cpu_pct":     18.3,
  "req_per_min":     120,
  "latency_ms":      45,
  "active_sessions": null
}
```

Fields are `null` when the underlying source (Prometheus / DynamoDB) is
unreachable — the frontend handles this gracefully by showing "—".

## VPC Peering — how Prometheus data flows

```
lks-monitoring-vpc (10.1.0.0/16)     lks-vpc (10.0.0.0/16)
┌─────────────────┐                  ┌────────────────────────┐
│ Prometheus :9090│◄─── scrapes ─────│ Analytics /metrics     │
│                 │                  │ (this service)         │
│                 │                  └────────────────────────┘
└────────┬────────┘
         │ PromQL query (HTTP over pcx-lks-2026)
         ▼
┌─────────────────┐
│ Analytics       │
│ /api/stats/     │
│ summary         │
└─────────────────┘
```

The analytics service reads `PROMETHEUS_URL` (a private IP in lks-monitoring-vpc)
and fires PromQL queries to retrieve ECS CPU and latency data.
Traffic crosses the VPC Peering connection — never the public internet.

## Local development

```bash
cd analytics
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # Leave PROMETHEUS_URL blank for local dev
python src/main.py          # http://localhost:5000
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | 5000 | HTTP port |
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_NAME` | lksdb | Database name |
| `DB_USER` | lksadmin | Database user |
| `DB_PASSWORD` | — | Database password |
| `AWS_REGION` | us-east-1 | AWS region |
| `PROMETHEUS_URL` | — | Prometheus endpoint in lks-monitoring-vpc (e.g. `http://10.1.1.x:9090`) |
