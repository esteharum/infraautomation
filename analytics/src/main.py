import os
import asyncio
import httpx
import psycopg2
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import time

load_dotenv()

app = FastAPI(title="lks-analytics", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Prometheus metrics (exposed at /metrics for Prometheus scraping) ──
REQUEST_COUNT = Counter(
    "analytics_requests_total",
    "Total requests to the analytics service",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "analytics_request_duration_seconds",
    "Request latency in seconds",
    ["endpoint"],
)

# ── DB helper ─────────────────────────────────────────────
def get_db():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        dbname=os.getenv("DB_NAME", "lksdb"),
        user=os.getenv("DB_USER", "lksadmin"),
        password=os.getenv("DB_PASSWORD", "password"),
        connect_timeout=5,
    )

# ── Prometheus query helper ────────────────────────────────
async def query_prometheus(promql: str) -> float | None:
    prom_url = os.getenv("PROMETHEUS_URL", "")
    if not prom_url:
        return None
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            r = await client.get(
                f"{prom_url}/api/v1/query",
                params={"query": promql},
            )
            data = r.json()
            results = data.get("data", {}).get("result", [])
            if results:
                return float(results[0]["value"][1])
    except Exception:
        pass
    return None


# ── Health check ──────────────────────────────────────────
@app.get("/api/stats/health")
def health():
    return {"status": "ok", "service": "lks-analytics"}


# ── Prometheus metrics endpoint ───────────────────────────
@app.get("/metrics")
def metrics():
    """Exposed for Prometheus scraping via VPC Peering."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# ── Summary endpoint (polled by MetricsBar in frontend) ───
@app.get("/api/stats/summary")
async def summary():
    start = time.time()
    result = {}

    # Total users — from RDS PostgreSQL
    try:
        conn = get_db()
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM users")
            result["total_users"] = cur.fetchone()[0]
        conn.close()
    except Exception:
        result["total_users"] = None

    # ECS CPU utilisation — from Prometheus via VPC Peering
    ecs_cpu = await query_prometheus(
        'avg(rate(container_cpu_usage_seconds_total{container!=""}[1m])) * 100'
    )
    result["ecs_cpu_pct"] = round(ecs_cpu, 1) if ecs_cpu is not None else None

    # API request rate — from Prometheus
    req_rate = await query_prometheus(
        'sum(rate(analytics_requests_total[1m])) * 60'
    )
    result["req_per_min"] = round(req_rate) if req_rate is not None else None

    # P95 API latency — from Prometheus
    latency = await query_prometheus(
        'histogram_quantile(0.95, rate(analytics_request_duration_seconds_bucket[5m])) * 1000'
    )
    result["latency_ms"] = round(latency) if latency is not None else None

    # Active sessions — from DynamoDB (count not expired)
    result["active_sessions"] = None  # implement with boto3 if needed

    duration = time.time() - start
    REQUEST_COUNT.labels("GET", "/api/stats/summary", "200").inc()
    REQUEST_LATENCY.labels("/api/stats/summary").observe(duration)

    return result


# ── Per-endpoint stats ─────────────────────────────────────
@app.get("/api/stats/users")
async def user_stats():
    try:
        conn = get_db()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    COUNT(*)                             AS total,
                    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days')
                                                         AS last_7_days,
                    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days')
                                                         AS last_30_days
                FROM users
            """)
            row = cur.fetchone()
        conn.close()
        return {
            "total":       row[0],
            "last_7_days": row[1],
            "last_30_days": row[2],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=int(os.getenv("PORT", 5000)), reload=False)
