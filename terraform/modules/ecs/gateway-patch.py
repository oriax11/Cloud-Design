"""Startup patch for the api-gateway image (oriax11/api-gateway-app).

Applied by the ECS task definition before the server starts. Idempotent.

1. Stops the Flask proxy from copying upstream hop-by-hop headers (e.g.
   Connection) into the response. waitress rejects those with an
   AssertionError, which causes HTTP 500 for any client that sends
   "Connection: close" (including the ALB health checker).
2. Adds a small root route so the ALB health check and a browser get a 200
   instead of the default 404.
3. Adds Cognito JWT enforcement on /api/* using a dependency-free RS256
   verifier (the image has no PyJWT/cryptography, and Alpine makes them hard
   to install).

Remove this once the image is rebuilt with a proper fix.
"""

import os

PROXY = "/usr/src/app/proxy.py"
APP_INIT = "/usr/src/app/__init__.py"
AUTH = "/usr/src/app/auth.py"

AUTH_SOURCE = '''import base64
import hashlib
import json
import os
import time

import requests
from flask import jsonify, request

REGION = os.getenv("COGNITO_REGION")
POOL_ID = os.getenv("COGNITO_USER_POOL_ID")
CLIENT_ID = os.getenv("COGNITO_APP_CLIENT_ID")

ISSUER = f"https://cognito-idp.{REGION}.amazonaws.com/{POOL_ID}"
JWKS_URL = ISSUER + "/.well-known/jwks.json"

_cache = {"keys": None, "ts": 0.0}


def _b64d(value):
    value += "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value)


def _jwks():
    if _cache["keys"] is None or time.time() - _cache["ts"] > 3600:
        resp = requests.get(JWKS_URL, timeout=5)
        resp.raise_for_status()
        _cache["keys"] = resp.json().get("keys", [])
        _cache["ts"] = time.time()
    return _cache["keys"]


def _verify(token):
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
    except ValueError:
        return None

    try:
        header = json.loads(_b64d(header_b64))
    except Exception:
        return None

    if header.get("alg") != "RS256":
        return None

    kid = header.get("kid")
    key = next((k for k in _jwks() if k.get("kid") == kid), None)
    if not key:
        return None

    n = int.from_bytes(_b64d(key["n"]), "big")
    e = int.from_bytes(_b64d(key["e"]), "big")
    sig = int.from_bytes(_b64d(sig_b64), "big")

    klen = (n.bit_length() + 7) // 8
    em = pow(sig, e, n).to_bytes(klen, "big")

    digest = hashlib.sha256((header_b64 + "." + payload_b64).encode()).digest()
    digestinfo = bytes.fromhex("3031300d060960864801650304020105000420") + digest
    expected = b"\\x00\\x01" + b"\\xff" * (klen - len(digestinfo) - 3) + b"\\x00" + digestinfo
    if em != expected:
        return None

    try:
        payload = json.loads(_b64d(payload_b64))
    except Exception:
        return None

    if payload.get("iss") != ISSUER:
        return None
    if payload.get("exp", 0) < time.time():
        return None
    if payload.get("token_use") not in ("access", "id"):
        return None

    if CLIENT_ID:
        if payload.get("token_use") == "id" and payload.get("aud") != CLIENT_ID:
            return None
        if payload.get("token_use") == "access" and payload.get("client_id") not in (None, CLIENT_ID):
            return None

    return payload


def check():
    path = request.path or ""
    if not path.startswith("/api/"):
        return None
    if request.method == "OPTIONS":
        return None

    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return jsonify(error="missing bearer token"), 401

    token = header.split(" ", 1)[1].strip()
    if not _verify(token):
        return jsonify(error="invalid or expired token"), 401

    return None
'''

WRAPPER = '''

# --- Cognito auth wrapper (added by ecs/gateway-patch.py) ---
from app import auth as _auth  # noqa: E402

_orig_create_app = create_app


def create_app(*args, **kwargs):  # noqa: F811
    application = _orig_create_app(*args, **kwargs)
    application.before_request(_auth.check)
    return application
'''


def patch_proxy():
    with open(PROXY) as f:
        src = f.read()
    fixed = src.replace("response.headers.items()", "[]")
    if fixed != src:
        with open(PROXY, "w") as f:
            f.write(fixed)


def patch_root_route():
    with open(APP_INIT) as f:
        src = f.read()
    if "_root" in src:
        return
    marker = "    return app"
    route = (
        "    @app.route(\"/\")\n"
        "    def _root():\n"
        "        return jsonify(status=\"ok\", service=\"api-gateway\")\n"
        "\n"
        "    return app"
    )
    src = src.replace(marker, route, 1)
    with open(APP_INIT, "w") as f:
        f.write(src)


def patch_auth():
    with open(AUTH, "w") as f:
        f.write(AUTH_SOURCE)

    with open(APP_INIT) as f:
        src = f.read()
    if "_orig_create_app" not in src:
        src = src + WRAPPER
        with open(APP_INIT, "w") as f:
            f.write(src)


patch_proxy()
patch_root_route()
patch_auth()
