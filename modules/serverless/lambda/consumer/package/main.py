"""Lambda consumidora: lee mensajes SQS y persiste eventos PagoPendiente en RDS PostgreSQL."""

import json
import os

import pg8000

DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]


def _connect():
    return pg8000.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
    )


def _ensure_table(cur) -> None:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS pagos_pendientes (
            id SERIAL PRIMARY KEY,
            payment_id VARCHAR(128) NOT NULL,
            amount NUMERIC(14, 2),
            currency VARCHAR(8),
            event_type VARCHAR(64),
            payload JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        """
    )


def handler(event, context):
    records = event.get("Records", [])
    if not records:
        return {"statusCode": 200}

    conn = _connect()
    try:
        cur = conn.cursor()
        _ensure_table(cur)
        for record in records:
            body = json.loads(record["body"])
            cur.execute(
                """
                INSERT INTO pagos_pendientes (payment_id, amount, currency, event_type, payload)
                VALUES (%s, %s, %s, %s, CAST(%s AS jsonb));
                """,
                (
                    body.get("paymentId"),
                    body.get("amount"),
                    body.get("currency"),
                    body.get("eventType"),
                    json.dumps(body),
                ),
            )
        conn.commit()
    finally:
        conn.close()
    return {"statusCode": 200}
