import logging
import time
from flask import Blueprint, request, jsonify
from db import get_conn, put_conn, is_ready
from sqs import publish_event

log = logging.getLogger(__name__)
users_bp = Blueprint("users", __name__)


def _rows_to_list(rows, description):
    cols = [d[0] for d in description]
    result = []
    for row in rows:
        d = dict(zip(cols, row))
        for k, v in d.items():
            if hasattr(v, "isoformat"):
                d[k] = v.isoformat()
        result.append(d)
    return result


def _check_db():
    """
    Wait up to 10s for DB to become ready before returning 503.
    This handles race where request arrives while init_db() is still retrying.
    """
    if is_ready():
        return None
    # Brief wait — DB might just be finishing its last retry
    for _ in range(10):
        time.sleep(1)
        if is_ready():
            return None
    return jsonify({
        "error": "Service Unavailable",
        "message": "Database is not ready yet. Please retry in a moment."
    }), 503


# ── GET /api/users ──────────────────────────────────────────
@users_bp.get("/")
def list_users():
    err = _check_db()
    if err:
        return err
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, name, email, institution, position, phone, created_at "
                "FROM users ORDER BY id ASC"
            )
            rows = cur.fetchall()
            desc = cur.description
        return jsonify(_rows_to_list(rows, desc))
    finally:
        put_conn(conn)


# ── GET /api/users/:id ──────────────────────────────────────
@users_bp.get("/<int:user_id>")
def get_user(user_id):
    err = _check_db()
    if err:
        return err
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, name, email, institution, position, phone, created_at "
                "FROM users WHERE id = %s",
                (user_id,),
            )
            row = cur.fetchone()
            desc = cur.description
        if not row:
            return jsonify({"error": "User not found"}), 404
        return jsonify(_rows_to_list([row], desc)[0])
    finally:
        put_conn(conn)


# ── POST /api/users ─────────────────────────────────────────
@users_bp.post("/")
def create_user():
    err = _check_db()
    if err:
        return err
    data = request.get_json(silent=True) or {}
    name  = (data.get("name")  or "").strip()
    email = (data.get("email") or "").strip()
    if not name or not email:
        return jsonify({"error": "name and email are required"}), 400

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO users (name, email, institution, position, phone) "
                "VALUES (%s, %s, %s, %s, %s) "
                "RETURNING id, name, email, institution, position, phone, created_at",
                (name, email,
                 data.get("institution") or None,
                 data.get("position")    or None,
                 data.get("phone")       or None),
            )
            row  = cur.fetchone()
            desc = cur.description
        conn.commit()
        user = _rows_to_list([row], desc)[0]
        publish_event("user.created", {"userId": user["id"], "email": user["email"]})
        return jsonify(user), 201
    except Exception as e:
        conn.rollback()
        if getattr(e, "pgcode", None) == "23505":
            return jsonify({"error": "Email already exists"}), 409
        raise
    finally:
        put_conn(conn)


# ── PUT /api/users/:id ──────────────────────────────────────
@users_bp.put("/<int:user_id>")
def update_user(user_id):
    err = _check_db()
    if err:
        return err
    data = request.get_json(silent=True) or {}
    name  = (data.get("name")  or "").strip()
    email = (data.get("email") or "").strip()
    if not name or not email:
        return jsonify({"error": "name and email are required"}), 400

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE users "
                "SET name=%s, email=%s, institution=%s, position=%s, phone=%s, updated_at=NOW() "
                "WHERE id=%s "
                "RETURNING id, name, email, institution, position, phone, updated_at",
                (name, email,
                 data.get("institution") or None,
                 data.get("position")    or None,
                 data.get("phone")       or None,
                 user_id),
            )
            row  = cur.fetchone()
            desc = cur.description
        if not row:
            conn.rollback()
            return jsonify({"error": "User not found"}), 404
        conn.commit()
        user = _rows_to_list([row], desc)[0]
        publish_event("user.updated", {"userId": user["id"]})
        return jsonify(user)
    except Exception as e:
        conn.rollback()
        if getattr(e, "pgcode", None) == "23505":
            return jsonify({"error": "Email already exists"}), 409
        raise
    finally:
        put_conn(conn)


# ── DELETE /api/users/:id ───────────────────────────────────
@users_bp.delete("/<int:user_id>")
def delete_user(user_id):
    err = _check_db()
    if err:
        return err
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
            deleted = cur.rowcount
        if not deleted:
            conn.rollback()
            return jsonify({"error": "User not found"}), 404
        conn.commit()
        publish_event("user.deleted", {"userId": user_id})
        return "", 204
    except Exception:
        conn.rollback()
        raise
    finally:
        put_conn(conn)
