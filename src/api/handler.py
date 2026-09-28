"""Internal echo API behind an internal ALB in mTLS verify mode.

The ALB has already authenticated the client certificate before this runs.
This handler authorises the client by certificate CN, validates the body and
echoes the message. Config is read once per cold start from SSM
/<function name>/config.
"""

import json
import logging
import os
import time
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_config = None


def load_config():
    global _config
    if _config is None:
        import boto3  # imported lazily so unit tests don't need it

        name = f"/{os.environ['AWS_LAMBDA_FUNCTION_NAME']}/config"
        value = boto3.client("ssm").get_parameter(Name=name, WithDecryption=True)["Parameter"]["Value"]
        _config = json.loads(value)
    return _config


def client_common_name(subject):
    """CN from the ALB's subject header, e.g. 'CN=smoke-test,O=Internal API (dev)'."""
    for part in (subject or "").split(","):
        key, _, value = part.strip().partition("=")
        if key == "CN":
            return value
    return None


def response(status, body, request_id):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json", "X-Request-Id": request_id},
        "body": json.dumps({**body, "request_id": request_id}),
    }


def handle(event, request_id):
    def error(status, message):
        return response(status, {"error": message}, request_id)

    headers = event.get("headers") or {}
    config = load_config()

    if event.get("path") != "/":
        return error(404, "Not found")
    if event.get("httpMethod") != "POST":
        return error(405, "Only POST is allowed")
    if client_common_name(headers.get("x-amzn-mtls-clientcert-subject")) not in config["allowed_client_common_names"]:
        return error(403, "Client certificate is not authorised for this API")
    if not headers.get("content-type", "").startswith("application/json"):
        return error(415, "Content-Type must be application/json")

    try:
        payload = json.loads(event.get("body") or "")
    except ValueError:
        return error(400, "Body must be valid JSON")

    message = payload.get("message") if isinstance(payload, dict) else None
    if not isinstance(message, str) or not message.strip():
        return error(400, "Body must contain a non-empty string 'message'")
    if len(message) > config["max_message_length"]:
        return error(400, f"'message' must be at most {config['max_message_length']} characters")

    timestamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
    return response(200, {"message": message, "timestamp": timestamp}, request_id)


def lambda_handler(event, context):
    started = time.monotonic()
    request_id = context.aws_request_id
    try:
        result = handle(event, request_id)
    except Exception:
        logger.exception("unhandled error")
        result = response(500, {"error": "Internal error"}, request_id)

    # One structured audit line per request (Lambda's JSON log format adds the timestamp).
    headers = event.get("headers") or {}
    logger.info("request", extra={
        "request_id": request_id,
        "method": event.get("httpMethod"),
        "path": event.get("path"),
        "status": result["statusCode"],
        "latency_ms": round((time.monotonic() - started) * 1000, 1),
        "client_subject": headers.get("x-amzn-mtls-clientcert-subject"),
        "client_serial": headers.get("x-amzn-mtls-clientcert-serial-number"),
    })
    return result
