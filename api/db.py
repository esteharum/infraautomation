import os
import time
import logging
import threading
import psycopg2
from psycopg2 import pool, OperationalError

log = logging.getLogger(__name__)

_pool: pool.ThreadedConnectionPool | None = None
_db_ready = False
_db_lock = threading.Lock()


def init_db():
    """
    Connect to RDS with retry backoff.
    AWS RDS PostgreSQL 15 requires SSL (rds.force_ssl=1 by default).
    Use sslmode=require — no CA cert needed (not verify-full).
    """
    global _pool, _db_ready

    dsn = dict(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 5432)),
        dbname=os.getenv("DB_NAME", "lksdb"),
        user=os.getenv("DB_USER", "lksadmin"),
        password=os.getenv("DB_PASSWORD", "password"),
        sslmode="require",
        connect_timeout=10,
    )

    attempt = 0
    while True:
        attempt += 1
        try:
            log.info(f"Connecting to PostgreSQL at {dsn['host']} (attempt {attempt})...")
            new_pool = pool.ThreadedConnectionPool(minconn=1, maxconn=10, **dsn)
            conn = new_pool.getconn()
            try:
                with conn.cursor() as cur:
                    cur.execute("""
                        CREATE TABLE IF NOT EXISTS users (
                            id          SERIAL PRIMARY KEY,
                            name        VARCHAR(255) NOT NULL,
                            email       VARCHAR(255) NOT NULL UNIQUE,
                            institution VARCHAR(255),
                            position    VARCHAR(255),
                            phone       VARCHAR(50),
                            created_at  TIMESTAMPTZ DEFAULT NOW(),
                            updated_at  TIMESTAMPTZ DEFAULT NOW()
                        )
                    """)
                conn.commit()
            finally:
                new_pool.putconn(conn)

            with _db_lock:
                _pool = new_pool
                _db_ready = True
            log.info("PostgreSQL connected and schema ready")
            return

        except OperationalError as e:
            wait = min(2 ** attempt, 30)
            log.warning(f"DB connection failed (attempt {attempt}): {e} — retry in {wait}s")
            time.sleep(wait)


def is_ready() -> bool:
    return _db_ready


def get_conn():
    if _pool is None:
        raise RuntimeError("Database not available")
    return _pool.getconn()


def put_conn(conn):
    if _pool:
        _pool.putconn(conn)
