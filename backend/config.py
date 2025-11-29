from __future__ import annotations

import os
from datetime import timedelta
from pathlib import Path


def _get_required_env(key: str) -> str:
  """OBTEM VARIÁVEL DE AMBIENTE OBRIGATÓRIA. LANÇA ERRO SE NÃO EXISTIR."""
  value = os.getenv(key)
  if not value:
    raise ValueError(
      f"VARIÁVEL DE AMBIENTE OBRIGATÓRIA '{key}' NÃO FOI DEFINIDA. "
      f"COPIE O ARQUIVO env.example PARA .env E CONFIGURE AS VARIÁVEIS."
    )
  return value


def _get_database_url() -> str:
  """OBTEM URL DO BANCO DE DADOS. VALIDA SE ESTÁ DEFINIDA."""
  return _get_required_env("DATABASE_URL")


def _get_secret_key() -> str:
  """OBTEM SECRET_KEY. VALIDA SE ESTÁ DEFINIDA."""
  return _get_required_env("SECRET_KEY")


class Config:
  """Base configuration for the Flask application."""

  # VARIÁVEIS OBRIGATÓRIAS - DEVEM ESTAR NO ARQUIVO .env
  # VALIDAÇÃO ACONTECE QUANDO A CLASSE É DEFINIDA (EXCETO PARA TestConfig)
  SQLALCHEMY_DATABASE_URI = _get_database_url()
  SECRET_KEY = _get_secret_key()
  JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY") or _get_secret_key()
  
  SQLALCHEMY_TRACK_MODIFICATIONS = False

  # VARIÁVEIS OPCIONAIS COM VALORES PADRÃO
  JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=int(os.getenv("JWT_ACCESS_MINUTES", "30")))
  JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=int(os.getenv("JWT_REFRESH_DAYS", "7")))
  LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

  BASE_DIR = Path(__file__).resolve().parent


class TestConfig(Config):
  """CONFIGURAÇÃO PARA TESTES - USA VALORES PADRÃO SEGUROS."""
  TESTING = True
  # SOBRESCREVE AS VARIÁVEIS OBRIGATÓRIAS COM VALORES SEGUROS PARA TESTES
  SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
  SECRET_KEY = "test-secret-key-for-testing-only"
  JWT_SECRET_KEY = SECRET_KEY
  JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=5)





















