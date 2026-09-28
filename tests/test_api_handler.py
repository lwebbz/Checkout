import json
from types import SimpleNamespace

import pytest

from api import handler

CONFIG = {"allowed_client_common_names": ["smoke-test"], "max_message_length": 20}
SUBJECT = "CN=smoke-test,O=Internal API (dev)"


@pytest.fixture(autouse=True)
def config(monkeypatch):
    monkeypatch.setenv("AWS_LAMBDA_FUNCTION_NAME", "internal-api-test-api")
    monkeypatch.setattr(handler, "load_config", lambda: CONFIG)


def event(body='{"message": "hello"}', method="POST", path="/", subject=SUBJECT,
          content_type="application/json"):
    headers = {"content-type": content_type}
    if subject is not None:
        headers["x-amzn-mtls-clientcert-subject"] = subject
    return {"httpMethod": method, "path": path, "headers": headers, "body": body}


def call(evt):
    response = handler.lambda_handler(evt, SimpleNamespace(aws_request_id="req-123"))
    return response["statusCode"], json.loads(response["body"]), response["headers"]


def test_echoes_message_with_timestamp_and_request_id():
    status, body, headers = call(event())
    assert status == 200
    assert body["message"] == "hello"
    assert body["request_id"] == "req-123" == headers["X-Request-Id"]
    assert body["timestamp"].endswith("+00:00")


@pytest.mark.parametrize("path", ["/other", "/admin"])
def test_unknown_path_is_404(path):
    assert call(event(path=path))[0] == 404


def test_non_post_is_405():
    assert call(event(method="GET"))[0] == 405


@pytest.mark.parametrize("subject", [None, "CN=someone-else,O=x", "O=no-cn"])
def test_unlisted_or_missing_client_is_403(subject):
    assert call(event(subject=subject))[0] == 403


def test_wrong_content_type_is_415():
    assert call(event(content_type="text/plain"))[0] == 415


def test_content_type_parameters_are_accepted():
    assert call(event(content_type="application/json; charset=utf-8"))[0] == 200


@pytest.mark.parametrize("body", [
    "not json",
    "[]",
    '{"msg": "x"}',
    '{"message": 42}',
    '{"message": "   "}',
    '{"message": "' + "x" * 21 + '"}',
])
def test_invalid_payloads_are_400(body):
    status, resp, _ = call(event(body=body))
    assert status == 400 and resp["request_id"] == "req-123"


def test_config_failure_is_500_without_leaking_details(monkeypatch):
    def broken():
        raise RuntimeError("ssm unreachable")

    monkeypatch.setattr(handler, "load_config", broken)
    status, body, _ = call(event())
    assert status == 500 and body == {"error": "Internal error", "request_id": "req-123"}


@pytest.mark.parametrize("subject,cn", [
    ("CN=smoke-test,O=Internal API (dev)", "smoke-test"),
    ("O=x, CN=spaced", "spaced"),
    ("", None),
    (None, None),
])
def test_client_common_name(subject, cn):
    assert handler.client_common_name(subject) == cn
