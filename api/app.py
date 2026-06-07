import os
import time
import logging
import threading
import urllib.request
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import db
from routes.users import users_bp
from metrics import metrics_app, increment_request, increment_error

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}'
)
log = logging.getLogger(__name__)

app = Flask(__name__)
app.url_map.strict_slashes = False
CORS(app, origins=os.getenv("CORS_ORIGIN", "*"))

@app.before_request
def count_request():
    increment_request()

@app.after_request
def log_request(response):
    if response.status_code >= 500:
        increment_error()
    return response

@app.get("/api/health")
def health():
    return jsonify({
        "status": "ok",
        "service": "lks-api",
        "db": "connected" if db.is_ready() else "connecting",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })

# ── Status proxy — check Prometheus & Grafana dari server side ─
# Frontend hit /api/status, API yang reach ke Oregon via VPC peering
# sehingga tidak ada CORS / ERR_NAME_NOT_RESOLVED di browser
def _check_url(url: str, timeout: int = 4) -> bool:
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status < 500
    except Exception:
        return False

@app.get("/api/status")
def status():
    prom_url = os.getenv("PROMETHEUS_URL", "")
    graf_url = os.getenv("GRAFANA_URL", "")
    prom_ok  = _check_url(f"{prom_url}/-/healthy") if prom_url else False
    graf_ok  = _check_url(f"{graf_url}/api/health") if graf_url else False
    return jsonify({
        "prometheus": {"url": prom_url, "status": "online" if prom_ok else "offline"},
        "grafana":    {"url": graf_url,  "status": "online" if graf_ok  else "offline"},
        "db":         "connected" if db.is_ready() else "connecting",
        "timestamp":  time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })

app.register_blueprint(users_bp, url_prefix="/api/users")

@app.errorhandler(404)
def not_found(_e):
    return jsonify({"error": "Not Found"}), 404

@app.errorhandler(Exception)
def server_error(e):
    log.exception("Unhandled error")
    return jsonify({"error": "Internal Server Error", "message": str(e)}), 500

def run_metrics():
    metrics_port = int(os.getenv("METRICS_PORT", 9100))
    log.info(f"Metrics server on :{metrics_port}")
    metrics_app.run(host="0.0.0.0", port=metrics_port, use_reloader=False)

def init_db_background():
    db.init_db()

if __name__ == "__main__":
    threading.Thread(target=run_metrics, daemon=True).start()
    threading.Thread(target=init_db_background, daemon=False).start()
    port = int(os.getenv("PORT", 8080))
    log.info(f"lks-api listening on :{port}")
    app.run(host="0.0.0.0", port=port, use_reloader=False)
