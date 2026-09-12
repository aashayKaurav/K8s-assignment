from flask import Flask, jsonify, request
from flask_cors import CORS
from models import init_db, get_all_items, create_item, delete_item, check_db_connection, check_table_exists

app = Flask(__name__)
CORS(app)


@app.before_request
def ensure_db():
    if not hasattr(app, "_db_initialized"):
        try:
            init_db()
            app._db_initialized = True
        except Exception as e:
            app.logger.error(f"DB init failed: {e}")


@app.route("/api/health")
def health():
    """Liveness probe — checks DB connection is alive."""
    if check_db_connection():
        return jsonify({"status": "healthy"}), 200
    return jsonify({"status": "unhealthy"}), 503


@app.route("/api/ready")
def ready():
    """Readiness probe — checks DB table exists."""
    if check_table_exists():
        return jsonify({"status": "ready"}), 200
    return jsonify({"status": "not ready"}), 503


@app.route("/api/items", methods=["GET"])
def list_items():
    try:
        items = get_all_items()
        return jsonify(items), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/items", methods=["POST"])
def add_item():
    data = request.get_json()
    if not data or not data.get("name"):
        return jsonify({"error": "name is required"}), 400

    try:
        item = create_item(data["name"], data.get("description", ""))
        return jsonify(item), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/items/<int:item_id>", methods=["DELETE"])
def remove_item(item_id):
    try:
        deleted = delete_item(item_id)
        if deleted:
            return jsonify({"message": "deleted"}), 200
        return jsonify({"error": "not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
