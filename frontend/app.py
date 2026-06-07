import os
from flask import Flask, render_template, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

API_URL        = os.getenv("API_URL", "")
GRAFANA_URL    = os.getenv("GRAFANA_URL", "")
PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "")


@app.get("/")
@app.get("/users")
def index():
    return render_template("index.html",
                           api_url=API_URL,
                           grafana_url=GRAFANA_URL,
                           prometheus_url=PROMETHEUS_URL)


@app.get("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 3000))
    app.run(host="0.0.0.0", port=port, use_reloader=False)