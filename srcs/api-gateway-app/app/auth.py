"""Cognito JWT enforcement for the api-gateway.

Verifies the RS256 Bearer token on every request under /api/ using the user
pool JWKS. Implemented without PyJWT/cryptography (the image is Alpine and
those packages are heavy to install): RSA PKCS#1 v1.5 signature verification
is done with the stdlib plus `requests` for the JWKS fetch.
"""

import base64
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
    expected = b"\x00\x01" + b"\xff" * (klen - len(digestinfo) - 3) + b"\x00" + digestinfo
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
