from __future__ import annotations

import logging
from typing import Any

from flask import Flask, jsonify
from flask_cors import CORS

from .config import Config
from .extensions import db, jwt, migrate
from .routes import api_bp
from .seed import init_seed


def create_app(config_class: type[Config] = Config) -> Flask:
  app = Flask(__name__)
  app.config.from_object(config_class)

  _configure_logging(app)
  _register_extensions(app)
  _register_blueprints(app)
  _register_healthcheck(app)
  _enable_cors(app)
  _init_seed(app)

  return app


def _configure_logging(app: Flask) -> None:
  level = getattr(logging, app.config.get("LOG_LEVEL", "INFO").upper(), logging.INFO)
  logging.basicConfig(level=level)
  logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)


def _register_extensions(app: Flask) -> None:
  db.init_app(app)
  migrate.init_app(app, db)
  jwt.init_app(app)


def _register_blueprints(app: Flask) -> None:
  app.register_blueprint(api_bp, url_prefix="/api")


def _enable_cors(app: Flask) -> None:
  # Allow cross-origin requests for the API when running Flutter Web locally.
  CORS(
    app,
    resources={r"/api/*": {"origins": "*"}},
    supports_credentials=False,
    allow_headers=["Content-Type", "Authorization"],
    methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  )


def _register_healthcheck(app: Flask) -> None:
  @app.route("/health")
  def health() -> Any:
    return jsonify({"status": "ok"})


def _init_seed(app: Flask) -> None:
  """INICIALIZA OS SEEDS DO BANCO DE DADOS APÓS O APP SER CRIADO."""
  with app.app_context():
    # GARANTIR QUE AS TABELAS EXISTAM ANTES DE EXECUTAR O SEED
    try:
      db.create_all()
      init_seed(app)
    except Exception as e:
      logging.warning(f"AVISO: NÃO FOI POSSÍVEL EXECUTAR SEED: {e}")


app = create_app()

if __name__ == "__main__":
  app.run(debug=True)













