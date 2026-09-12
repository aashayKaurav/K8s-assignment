import psycopg2
from config import Config


def get_connection():
    return psycopg2.connect(Config.get_dsn())


def init_db():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    description TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        conn.commit()
    finally:
        conn.close()


def get_all_items():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, description, created_at FROM items ORDER BY id DESC")
            rows = cur.fetchall()
            return [
                {
                    "id": row[0],
                    "name": row[1],
                    "description": row[2],
                    "created_at": row[3].isoformat() if row[3] else None,
                }
                for row in rows
            ]
    finally:
        conn.close()


def create_item(name, description):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO items (name, description) VALUES (%s, %s) RETURNING id, name, description, created_at",
                (name, description),
            )
            row = cur.fetchone()
        conn.commit()
        return {
            "id": row[0],
            "name": row[1],
            "description": row[2],
            "created_at": row[3].isoformat() if row[3] else None,
        }
    finally:
        conn.close()


def delete_item(item_id):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM items WHERE id = %s RETURNING id", (item_id,))
            deleted = cur.fetchone()
        conn.commit()
        return deleted is not None
    finally:
        conn.close()


def check_db_connection():
    try:
        conn = get_connection()
        conn.close()
        return True
    except Exception:
        return False


def check_table_exists():
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute(
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'items')"
            )
            exists = cur.fetchone()[0]
        conn.close()
        return exists
    except Exception:
        return False
