# ── Stage 1: Install dependencies ───────────────────────────
FROM python:3.13-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ─────────────────────────────────────────
FROM python:3.13-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local
COPY . .

RUN useradd -m -r appuser
USER appuser

EXPOSE 3000

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# API_URL injected at runtime via ECS Task Definition environment variable.
# No build-time baking needed — Flask renders it server-side into the HTML template.
ENV API_URL=""

CMD ["python", "app.py"]
