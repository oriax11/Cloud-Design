"""Startup patch for the inventory-app and billing-app images.

Enables SQLAlchemy connection pre-ping / recycling so pooled DB connections
that are dropped while idle (through ECS Service Connect -> PostgreSQL) are
transparently replaced instead of surfacing as HTTP 500
("SSL SYSCALL error: EOF detected").

Idempotent. Remove once the images are rebuilt with these engine options.
"""

import os

INVENTORY_INIT = "/usr/src/app/__init__.py"
BILLING_SERVER = "/usr/src/server.py"


def patch_inventory():
    if not os.path.exists(INVENTORY_INIT):
        return
    with open(INVENTORY_INIT) as f:
        src = f.read()
    if "SQLALCHEMY_ENGINE_OPTIONS" in src:
        return
    marker = "SQLALCHEMY_DATABASE_URI=DB_URI"
    if marker in src:
        replacement = (
            "SQLALCHEMY_DATABASE_URI=DB_URI,\n"
            '        SQLALCHEMY_ENGINE_OPTIONS={"pool_pre_ping": True, "pool_recycle": 280}'
        )
        src = src.replace(marker, replacement, 1)
        with open(INVENTORY_INIT, "w") as f:
            f.write(src)


def patch_billing():
    if not os.path.exists(BILLING_SERVER):
        return
    with open(BILLING_SERVER) as f:
        src = f.read()
    if "pool_pre_ping" in src:
        return
    src = src.replace(
        "create_engine(DB_URI)",
        "create_engine(DB_URI, pool_pre_ping=True, pool_recycle=280)",
        1,
    )
    with open(BILLING_SERVER, "w") as f:
        f.write(src)


patch_inventory()
patch_billing()
