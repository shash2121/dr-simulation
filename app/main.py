import os
import json
import socket
import datetime
import threading
import pymysql
import redis
import boto3
from flask import Flask, request, jsonify, render_template

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "3306")
DB_NAME = os.environ.get("DB_NAME", "dummydb")
DB_USER = os.environ.get("DB_USERNAME", "admin")
DB_PASS = os.environ.get("DB_PASSWORD", "")
REGION = os.environ.get("REGION", "unknown")
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL", "")
HOSTNAME = socket.gethostname()

sqs_stats = {"visible": 0, "in_flight": 0, "processed": 0, "errors": 0, "last_poll": None}


def get_db_conn():
    return pymysql.connect(
        host=DB_HOST, port=int(DB_PORT), database=DB_NAME,
        user=DB_USER, password=DB_PASS, connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )


def init_db():
    import time
    for attempt in range(10):
        try:
            conn = get_db_conn()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    region VARCHAR(50),
                    hostname VARCHAR(200),
                    data TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()
            cur.close()
            conn.close()
            print("DB initialized successfully")
            return
        except Exception as e:
            print(f"DB init attempt {attempt + 1}/10: {e}")
            time.sleep(3)
    print("DB init failed after 10 attempts — starting without DB")


def get_redis_client():
    try:
        return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_timeout=3)
    except Exception:
        return None


def get_sqs_client():
    if not SQS_QUEUE_URL:
        return None
    try:
        return boto3.client("sqs", region_name=REGION)
    except Exception:
        return None


def check_sqs():
    client = get_sqs_client()
    if not client:
        return None
    try:
        client.get_queue_attributes(QueueUrl=SQS_QUEUE_URL, AttributeNames=["ApproximateNumberOfMessages"])
        return True
    except Exception:
        return False


def write_event_to_db(payload):
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO events (region, hostname, data) VALUES (%s, %s, %s)",
        (REGION, HOSTNAME, payload),
    )
    eid = cur.lastrowid
    conn.commit()
    cur.close()
    conn.close()

    try:
        r = get_redis_client()
        if r:
            event_json = json.dumps({"id": eid, "region": REGION, "hostname": HOSTNAME, "data": payload, "created_at": datetime.datetime.utcnow().isoformat()})
            r.lpush("dr-sim:recent-events", event_json)
            r.ltrim("dr-sim:recent-events", 0, 99)
            r.zadd("dr-sim:event-rate", {str(eid): datetime.datetime.utcnow().timestamp()})
            r.zremrangebyscore("dr-sim:event-rate", "-inf", datetime.datetime.utcnow().timestamp() - 60)
            r.set("dr-sim:last-sync-at", datetime.datetime.utcnow().isoformat())
            r.set("dr-sim:last-event-id", str(eid))
    except Exception as e:
        print(f"Redis cache write failed: {e}")

    return eid


def sqs_poller():
    client = get_sqs_client()
    if not client:
        print("SQS poller: queue not configured, skipping")
        return

    print(f"SQS poller: started on {SQS_QUEUE_URL}")
    while True:
        try:
            attrs = client.get_queue_attributes(
                QueueUrl=SQS_QUEUE_URL,
                AttributeNames=["ApproximateNumberOfMessages", "ApproximateNumberOfMessagesNotVisible"],
            )
            sqs_stats["visible"] = int(attrs.get("Attributes", {}).get("ApproximateNumberOfMessages", 0))
            sqs_stats["in_flight"] = int(attrs.get("Attributes", {}).get("ApproximateNumberOfMessagesNotVisible", 0))
            sqs_stats["last_poll"] = datetime.datetime.utcnow().isoformat()

            resp = client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=5,
                MessageAttributeNames=["All"],
            )
            messages = resp.get("Messages", [])
            for msg in messages:
                try:
                    body = json.loads(msg.get("Body", '{"data":"unknown"}'))
                    payload = body.get("data", "unknown")
                    write_event_to_db(payload)
                    client.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
                    sqs_stats["processed"] += 1
                except Exception as e:
                    print(f"SQS poller: failed to process message: {e}")
                    sqs_stats["errors"] += 1

            if messages:
                print(f"SQS poller: processed {len(messages)} messages (total: {sqs_stats['processed']})")
        except Exception as e:
            print(f"SQS poller: error - {e}")
            import time
            time.sleep(5)


@app.route("/")
def root():
    return render_template("index.html")


@app.route("/health")
def health():
    db_ok, redis_ok, sqs_ok = False, False, None
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        db_ok = True
    except Exception:
        pass
    try:
        r = get_redis_client()
        if r:
            r.ping()
            redis_ok = True
    except Exception:
        pass
    sqs_ok = check_sqs()
    return jsonify({
        "status": "healthy" if db_ok else "degraded",
        "database": "connected" if db_ok else "disconnected",
        "redis": "connected" if redis_ok else "disconnected",
        "sqs": "connected" if sqs_ok else ("skipped" if sqs_ok is None else "disconnected"),
        "region": REGION,
        "hostname": HOSTNAME,
        "endpoints": {
            "db": f"{DB_HOST}:{DB_PORT}",
            "redis": f"{REDIS_HOST}:{REDIS_PORT}",
            "sqs": SQS_QUEUE_URL or "not configured",
        },
    }), (200 if db_ok else 503)


@app.route("/send-to-sqs", methods=["POST"])
def send_to_sqs():
    data = request.json or {}
    payload = data.get("data", f"event-{datetime.datetime.utcnow().isoformat()}")
    delay = data.get("delay", 0)

    if SQS_QUEUE_URL:
        try:
            client = get_sqs_client()
            resp = client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps({"data": payload}),
                DelaySeconds=min(int(delay), 900),
            )
            return jsonify({
                "status": "queued",
                "message_id": resp.get("MessageId"),
                "region": REGION,
                "queue_url": SQS_QUEUE_URL,
            })
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    else:
        try:
            eid = write_event_to_db(payload)
            return jsonify({"id": eid, "region": REGION, "status": "written (direct — no SQS configured)"})
        except Exception as e:
            return jsonify({"error": str(e)}), 500


@app.route("/sqs-stats")
def sqs_stats_endpoint():
    return jsonify({
        "queue_url": SQS_QUEUE_URL or "not configured",
        "region": REGION,
        "visible_messages": sqs_stats["visible"],
        "in_flight": sqs_stats["in_flight"],
        "processed": sqs_stats["processed"],
        "errors": sqs_stats["errors"],
        "last_poll": sqs_stats["last_poll"],
    })


@app.route("/write", methods=["POST"])
def write():
    data = request.json or {}
    payload = data.get("data", f"event-{datetime.datetime.utcnow().isoformat()}")
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO events (region, hostname, data) VALUES (%s, %s, %s)",
            (REGION, HOSTNAME, payload),
        )
        eid = cur.lastrowid
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"id": eid, "region": REGION, "status": "written"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/read")
def read():
    try:
        offset = int(request.args.get("offset", 0))
        limit = int(request.args.get("limit", 5))
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, region, hostname, data, created_at FROM events ORDER BY id DESC LIMIT %s OFFSET %s", (limit, offset))
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({
            "current_region": REGION,
            "count": len(rows),
            "events": [
                {
                    "id": r["id"], "region": r["region"],
                    "hostname": r["hostname"], "data": r["data"],
                    "created_at": r["created_at"].isoformat() if r["created_at"] else None,
                }
                for r in rows
            ],
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/events/count")
def events_count():
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM events")
        total = cur.fetchone()["COUNT(*)"]
        cur.close()
        conn.close()
        return jsonify({"total": total})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/redis-events")
def redis_events():
    try:
        r = get_redis_client()
        if not r:
            return jsonify({"error": "redis not reachable"}), 503
        raw = r.lrange("dr-sim:recent-events", 0, -1)
        events = [json.loads(item) for item in raw]
        return jsonify({"count": len(events), "events": events})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/failover-status")
def failover_status():
    try:
        r = get_redis_client()
        if not r:
            return jsonify({"error": "redis not reachable"}), 503
        cache_size = r.llen("dr-sim:recent-events")
        events_per_min = r.zcount("dr-sim:event-rate", "-inf", "+inf")
        last_sync = r.get("dr-sim:last-sync-at")
        last_event_id = r.get("dr-sim:last-event-id")
        last_sync_ist = None
        if last_sync:
            dt = datetime.datetime.fromisoformat(last_sync.decode())
            dt_ist = dt + datetime.timedelta(hours=5, minutes=30)
            last_sync_ist = dt_ist.strftime("%H:%M:%S IST")
        return jsonify({
            "cache_size": cache_size,
            "events_per_minute": events_per_min,
            "last_sync_ist": last_sync_ist,
            "last_event_id": last_event_id.decode() if last_event_id else None,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/redis-test")
def redis_test():
    try:
        r = get_redis_client()
        if not r:
            return jsonify({"error": "redis not reachable"}), 503
        n = r.incr("dr-sim-counter")
        return jsonify({"region": REGION, "counter": n, "hostname": HOSTNAME})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    init_db()
    if SQS_QUEUE_URL:
        t = threading.Thread(target=sqs_poller, daemon=True)
        t.start()
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)

init_db()
if SQS_QUEUE_URL:
    t = threading.Thread(target=sqs_poller, daemon=True)
    t.start()
