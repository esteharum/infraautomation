"""
Prometheus metrics for lks-api-service.
Exposed on a separate Flask app at port 9100 (/metrics).
Scraped by Prometheus in us-west-2 via Inter-Region VPC Peering pcx-lks-2026.
"""

import os
import time
import threading
from flask import Flask, Response

metrics_app = Flask("metrics")

_lock = threading.Lock()
_request_count = 0
_error_count = 0
_start_time = time.time()


def increment_request():
    global _request_count
    with _lock:
        _request_count += 1


def increment_error():
    global _error_count
    with _lock:
        _error_count += 1


def _prom_line(help_text, metric_type, name, labels, value):
    lbl = ",".join(f'{k}="{v}"' for k, v in labels.items())
    return (
        f"# HELP {name} {help_text}\n"
        f"# TYPE {name} {metric_type}\n"
        f"{name}{{{lbl}}} {value}\n"
    )


@metrics_app.get("/metrics")
def metrics():
    uptime = int(time.time() - _start_time)
    region = os.getenv("AWS_REGION", "us-east-1")
    lbl = {"service": "lks-api", "region": region}

    body = "\n".join([
        _prom_line("Total HTTP requests", "counter",
                   "lks_api_requests_total", lbl, _request_count),
        _prom_line("Total HTTP 5xx errors", "counter",
                   "lks_api_errors_total", lbl, _error_count),
        _prom_line("Seconds since service started", "gauge",
                   "lks_api_uptime_seconds", lbl, uptime),
    ])
    return Response(body, mimetype="text/plain; version=0.0.4; charset=utf-8")


@metrics_app.get("/health")
def health():
    return "OK", 200
