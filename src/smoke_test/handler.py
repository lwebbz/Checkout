"""Synthetic probe: calls the internal API as an in-VPC mTLS client.

Checks, against the private DNS name:
  1. client cert + valid body -> 200 echoing the message
  2. client cert + bad body   -> 400
  3. no client cert           -> TLS handshake rejected by the ALB

Emits ProbeSuccess (0/1) and ProbeLatency in CloudWatch Embedded Metric
Format; the ProbeSuccess alarm is the API's health signal. Never raises: a
failure is reported as ProbeSuccess=0 and the next scheduled run retries.
"""

import http.client
import json
import os
import ssl
import tempfile
import time
import uuid
from urllib.parse import urlparse


def load_config_and_cert(function_name):
    import boto3  # imported lazily so unit tests don't need it

    param = boto3.client("ssm").get_parameter(Name=f"/{function_name}/config", WithDecryption=True)
    config = json.loads(param["Parameter"]["Value"])
    secret = boto3.client("secretsmanager").get_secret_value(SecretId=config["client_cert_secret_arn"])
    return config, json.loads(secret["SecretString"])


def tls_context(cert, with_client_cert):
    context = ssl.create_default_context(cadata=cert["ca_cert_pem"])  # trust only our CA for the server
    if with_client_cert:
        # load_cert_chain needs a file; /tmp is private to this execution environment.
        with tempfile.NamedTemporaryFile("w", suffix=".pem") as pem:
            pem.write(cert["cert_pem"] + cert["private_key_pem"])
            pem.flush()
            context.load_cert_chain(pem.name)
    return context


def post(url, context, body):
    target = urlparse(url)
    conn = http.client.HTTPSConnection(target.hostname, 443, context=context, timeout=5)
    try:
        conn.request("POST", "/", body=json.dumps(body), headers={"Content-Type": "application/json"})
        response = conn.getresponse()
        return response.status, json.loads(response.read() or b"{}")
    finally:
        conn.close()


def mtls_rejected(url, context):
    """True if the ALB refuses a connection without a client cert.

    Only TLS errors and resets count: a timeout would mean a broken network
    path, not an enforced mTLS check.
    """
    try:
        post(url, context, {"message": "should never arrive"})
    except (ssl.SSLError, ConnectionResetError):
        return True
    return False


def run_checks(config, cert):
    url = config["api_url"]
    with_cert = tls_context(cert, with_client_cert=True)
    message = f"probe {uuid.uuid4()}"

    status, body = post(url, with_cert, {"message": message})
    results = {"valid_request": status == 200 and body.get("message") == message, "request_id": body.get("request_id")}

    status, _ = post(url, with_cert, {"not_message": "x"})
    results["invalid_payload"] = status == 400

    results["no_client_cert"] = mtls_rejected(url, tls_context(cert, with_client_cert=False))
    return results


def lambda_handler(event, context):
    function_name = os.environ["AWS_LAMBDA_FUNCTION_NAME"]
    started = time.monotonic()
    try:
        results = run_checks(*load_config_and_cert(function_name))
        success = results["valid_request"] and results["invalid_payload"] and results["no_client_cert"]
    except Exception as err:
        results, success = {"error": f"{type(err).__name__}: {err}"}, False

    latency_ms = round((time.monotonic() - started) * 1000, 1)
    print(json.dumps({  # Embedded Metric Format: CloudWatch turns this log line into metrics
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [{
                "Namespace": "InternalApi/Probe",
                "Dimensions": [["FunctionName"]],
                "Metrics": [{"Name": "ProbeSuccess", "Unit": "Count"}, {"Name": "ProbeLatency", "Unit": "Milliseconds"}],
            }],
        },
        "FunctionName": function_name,
        "ProbeSuccess": int(success),
        "ProbeLatency": latency_ms,
    }))

    summary = {"success": success, "latency_ms": latency_ms, "checks": results}
    print(json.dumps({"probe_result": summary}))
    return summary
