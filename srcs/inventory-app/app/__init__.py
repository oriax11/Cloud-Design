from flask import Flask
import os

from app.extensions import db
from app.movies import bp as bp_movies

DB_URI = (
    "postgresql://"
    f'{os.getenv("INVENTORY_DB_USER")}:{os.getenv("INVENTORY_DB_PASSWORD")}'
    f'@inventory-db:5432/{os.getenv("INVENTORY_DB_NAME")}'
)


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.from_mapping(
        SQLALCHEMY_DATABASE_URI=DB_URI,
        # Replace idle connections dropped through Service Connect instead of
        # surfacing "SSL SYSCALL error: EOF detected" as HTTP 500.
        SQLALCHEMY_ENGINE_OPTIONS={"pool_pre_ping": True, "pool_recycle": 280},
    )
    if test_config is not None:
        # load the test config if passed in
        app.config.from_mapping(test_config)

    app.register_blueprint(bp_movies)
    db.init_app(app)
    with app.app_context():
        db.create_all()

    return app
