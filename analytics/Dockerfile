# ── Stage 1: Install dependencies ────────────────────────
FROM python:3.13-slim AS builder

WORKDIR /app
COPY requirements.txt .

# Install to a local prefix so we can copy cleanly in stage 2
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ──────────────────────────────────────
FROM python:3.13-slim

WORKDIR /app

# Copy only installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY src/ ./src/

# Run as non-root user
RUN useradd -m -r appuser
USER appuser

EXPOSE 5000
ENV PYTHONUNBUFFERED=1

CMD ["python", "src/main.py"]
