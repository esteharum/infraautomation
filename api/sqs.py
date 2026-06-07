import os
import json
import logging
import time
import boto3
from botocore.exceptions import ClientError

log = logging.getLogger(__name__)
_client = None
QUEUE_URL = os.getenv("SQS_QUEUE_URL", "")


def _get_client():
    global _client
    if _client is None:
        _client = boto3.client("sqs", region_name=os.getenv("AWS_REGION", "us-east-1"))
    return _client


def publish_event(event_type: str, payload: dict):
    """Publish event to SQS. Silently skips if QUEUE_URL not configured."""
    if not QUEUE_URL:
        return
    try:
        message = json.dumps({
            "eventType": event_type,
            "payload": payload,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "source": "lks-api",
        })
        _get_client().send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=message,
            MessageAttributes={
                "EventType": {"DataType": "String", "StringValue": event_type},
            },
        )
        log.info(f"SQS event published: {event_type}")
    except ClientError as e:
        log.error(f"SQS publish failed: {e}")
