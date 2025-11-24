from __future__ import annotations

import os
from datetime import timedelta
from pathlib import Path


class Config:
  """Base configuration for the Flask application."""

  SQLALCHEMY_DATABASE_URI = os.getenv(
    "DATABASE_URL",
    "mysql+mysqlconnector://root:root@localhost:3306/clareza_diaria",
  )
  SQLALCHEMY_TRACK_MODIFICATIONS = False

  SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")
  JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", SECRET_KEY)
  JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=int(os.getenv("JWT_ACCESS_MINUTES", "30")))
  JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=int(os.getenv("JWT_REFRESH_DAYS", "7")))

  LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

  BASE_DIR = Path(__file__).resolve().parent


class TestConfig(Config):
  TESTING = True
  SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
  JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=5)



















