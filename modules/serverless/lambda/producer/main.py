"""Lambda productora: recibe HTTP (API Gateway), publica evento PagoPendiente en SQS."""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3

QUEUE_URL = os.environ["QUEUE_URL"]
sqs = boto3.client("sqs")


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "JSON inválido"}),
        }

    payment_id = body.get("payment_id") or str(uuid.uuid4())
    amount = body.get("amount", 0)
    currency = body.get("currency", "USD")

    message = {
        "eventType": "PagoPendiente",
        "paymentId": payment_id,
        "amount": amount,
        "currency": currency,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(message),
        MessageAttributes={
            "eventType": {
                "StringValue": "PagoPendiente",
                "DataType": "String",
            }
        },
    )

    return {
        "statusCode": 202,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Pago recibido y encolado para procesamiento asíncrono",
                "paymentId": payment_id,
                "eventType": "PagoPendiente",
            }
        ),
    }
