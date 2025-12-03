from __future__ import annotations

import re
from collections import Counter
from datetime import datetime, timedelta
from uuid import uuid4

from flask import Blueprint, jsonify, request
from flask_jwt_extended import (
  create_access_token,
  create_refresh_token,
  get_jwt_identity,
  jwt_required,
)
from sqlalchemy.exc import IntegrityError
from sqlalchemy import inspect as sqlalchemy_inspect

from ..extensions import db
from ..models import (
  Board,
  BoardItem,
  CareLink,
  Entry,
  Notification,
  Routine,
  RoutineStep,
  Share,
  User,
)
from ..cache import cache

api_bp = Blueprint("api", __name__)


def _get_json():
  if not request.is_json:
    return {}
  return request.get_json() or {}


def _current_user() -> User:
  identity = get_jwt_identity()
  try:
    user_id = int(identity)
  except (TypeError, ValueError):
    raise ValueError("Identidade de usuário inválida no token.")
  return User.query.get_or_404(user_id)


def _is_profissional_or_admin(user: User) -> bool:
  """
  VERIFICA SE O USUÁRIO É PROFISSIONAL OU ADMINISTRADOR.
  ADMINISTRADOR TEM ACESSO A TODAS AS FUNCIONALIDADES DE PROFISSIONAL.
  """
  if not user.perfil:
    return False
  perfil_lower = user.perfil.lower()
  return "profissional" in perfil_lower or "administrador" in perfil_lower


def _is_admin(user: User) -> bool:
  """VERIFICA SE O USUÁRIO É ADMINISTRADOR."""
  return user.perfil and "administrador" in user.perfil.lower()


def _parse_datetime(value: str | None, default: datetime | None = None) -> datetime | None:
  if not value:
    return default
  try:
    return datetime.fromisoformat(value)
  except ValueError:
    raise ValueError(f"Formato de data inválido: {value}. Use ISO 8601 (YYYY-MM-DDTHH:MM:SS).")


def _routine_to_dict(routine: Routine) -> dict:
  user = User.query.get(routine.user_id)
  return {
    "id": routine.id,
    "user_id": routine.user_id,
    "user_name": user.nome_completo if user else None,
    "titulo": routine.titulo,
    "lembrete": routine.lembrete,
    "steps": [
      {
        "id": step.id,
        "descricao": step.descricao,
        "duracao": step.duracao,
        "ordem": step.ordem,
      }
      for step in routine.steps
    ],
    "created_at": routine.created_at.isoformat(),
  }


def _entry_to_dict(entry: Entry) -> dict:
  user = User.query.get(entry.user_id)
  return {
    "id": entry.id,
    "user_id": entry.user_id,
    "user_name": user.nome_completo if user else None,
    "tipo": entry.tipo,
    "texto": entry.texto,
    "midia_url": entry.midia_url,
    "tags": entry.tags_list(),
    "timestamp": entry.timestamp.isoformat(),
  }


def _board_to_dict(board: Board) -> dict:
  return {
    "id": board.id,
    "nome": board.nome,
    "items": [_board_item_to_dict(item) for item in board.items],
    "created_at": board.created_at.isoformat(),
  }


def _board_item_to_dict(item: BoardItem) -> dict:
  return {
    "id": item.id,
    "texto": item.texto,
    "img_url": item.img_url,
    "audio_url": item.audio_url,
    "emoji": item.emoji,
    "categoria": item.categoria,
  }


@api_bp.errorhandler(ValueError)
def handle_value_error(exc: ValueError):
  return jsonify({"message": str(exc)}), 400


@api_bp.errorhandler(IntegrityError)
def handle_integrity_error(exc: IntegrityError):
  db.session.rollback()
  return jsonify({"message": "Violação de integridade do banco de dados.", "detail": str(exc.orig)}), 400


@api_bp.route("/auth/signup", methods=["POST"])
def signup():
  data = _get_json()
  email = data.get("email", "").strip().lower()
  password = data.get("senha")
  role = (data.get("role") or "viewer").strip().lower()
  nome_completo = (data.get("nomeCompleto") or "").strip()
  perfil = (data.get("quemE") or "").strip()
  preferencias = data.get("preferenciasSensoriais")

  if not email or not password:
    return jsonify({"message": "Email e senha são obrigatórios."}), 400

  if not nome_completo:
    return jsonify({"message": "Nome completo é obrigatório."}), 400

  if User.query.filter_by(email=email).first():
    return jsonify({"message": "Email já cadastrado."}), 400

  user = User(
    email=email,
    role=role,
    nome_completo=nome_completo,
    perfil=perfil or None,
    preferencias_sensoriais=(preferencias or None),
  )
  user.set_password(password)
  db.session.add(user)
  db.session.commit()

  access = create_access_token(identity=str(user.id))
  refresh = create_refresh_token(identity=str(user.id))

  return (
    jsonify(
      {
        "message": "Conta criada com sucesso.",
        "access_token": access,
        "refresh_token": refresh,
        "user": {
          "id": user.id,
          "email": user.email,
          "role": user.role,
          "nomeCompleto": user.nome_completo,
          "perfil": user.perfil,
          "preferenciasSensoriais": user.preferencias_sensoriais,
        },
      }
    ),
    201,
  )


@api_bp.route("/auth/login", methods=["POST"])
def login():
  data = _get_json()
  email = data.get("email", "").strip().lower()
  password = data.get("senha")

  if not email or not password:
    return jsonify({"message": "Email e senha são obrigatórios."}), 400

  user = User.query.filter_by(email=email).first()
  if not user or not user.check_password(password):
    return jsonify({"message": "Credenciais inválidas."}), 401

  access = create_access_token(identity=str(user.id))
  refresh = create_refresh_token(identity=str(user.id))

  return jsonify(
    {
      "message": "Login realizado com sucesso.",
      "access_token": access,
      "refresh_token": refresh,
      "user": {
        "id": user.id,
        "email": user.email,
        "role": user.role,
        "nomeCompleto": user.nome_completo,
        "perfil": user.perfil,
        "preferenciasSensoriais": user.preferencias_sensoriais,
      },
    }
  )


@api_bp.route("/auth/change-password", methods=["PUT"])
@jwt_required()
def change_password():
  user = _current_user()
  data = _get_json()
  senha_atual = data.get("senha_atual")
  nova_senha = data.get("nova_senha")

  if not senha_atual or not nova_senha:
    return jsonify({"message": "Senha atual e nova senha são obrigatórias."}), 400

  if not user.check_password(senha_atual):
    return jsonify({"message": "Senha atual incorreta."}), 401

  if len(nova_senha) < 6:
    return jsonify({"message": "A nova senha deve ter pelo menos 6 caracteres."}), 400

  user.set_password(nova_senha)
  db.session.commit()

  return jsonify({"message": "Senha alterada com sucesso."}), 200


@api_bp.route("/routines", methods=["GET"])
@jwt_required()
def list_routines():
  user = _current_user()
  
  # TENTAR BUSCAR DO CACHE
  cache_key = f"routines:user:{user.id}"
  cached_routines = cache.get(cache_key)
  if cached_routines is not None:
    return jsonify(cached_routines)
  
  # INCLUIR ROTINAS DO PRÓPRIO USUÁRIO
  routines = list(user.routines)
  
  # SE FOR CUIDADOR, INCLUIR ROTINAS DA PESSOA COM TEA VINCULADA
  if user.perfil and "cuidador" in user.perfil.lower():
    accepted_links = CareLink.query.filter_by(
      cuidador_id=user.id,
      status="accepted"
    ).all()
    
    for link in accepted_links:
      pessoa_tea = User.query.get(link.pessoa_tea_id)
      if pessoa_tea:
        routines.extend(pessoa_tea.routines)
  
  # SE FOR PESSOA COM TEA, INCLUIR ROTINAS DO CUIDADOR VINCULADO
  if user.perfil and "tea" in user.perfil.lower():
    accepted_links = CareLink.query.filter_by(
      pessoa_tea_id=user.id,
      status="accepted"
    ).all()
    
    for link in accepted_links:
      cuidador = User.query.get(link.cuidador_id)
      if cuidador:
        routines.extend(cuidador.routines)
  
  # SE FOR PROFISSIONAL OU ADMINISTRADOR, INCLUIR ROTINAS COMPARTILHADAS
  if _is_profissional_or_admin(user):
    shares = Share.query.filter_by(viewer_id=user.id).all()
    for share in shares:
      # VERIFICAR SE HÁ NOTIFICAÇÃO PENDENTE PARA ESTE SHARE
      # SE HOUVER, NÃO INCLUIR ROTINAS (AINDA NÃO FOI ACEITO)
      try:
        inspector = sqlalchemy_inspect(Notification)
        has_share_id = 'share_id' in [col.name for col in inspector.columns]
        
        if has_share_id:
          pending_notification = Notification.query.filter_by(
            share_id=share.id,
            tipo="share_request",
            lida=False
          ).first()
          
          if pending_notification:
            continue  # PULAR SHARES PENDENTES
      except Exception:
        pass
      
      owner = User.query.get(share.owner_id)
      if owner:
        # INCLUIR ROTINAS DO OWNER
        routines.extend(owner.routines)
        
        # SE O OWNER FOR CUIDADOR, INCLUIR ROTINAS DA PESSOA COM TEA VINCULADA
        if owner.perfil and "cuidador" in owner.perfil.lower():
          accepted_links = CareLink.query.filter_by(
            cuidador_id=owner.id,
            status="accepted"
          ).all()
          for link in accepted_links:
            pessoa_tea = User.query.get(link.pessoa_tea_id)
            if pessoa_tea:
              routines.extend(pessoa_tea.routines)
        
        # SE O OWNER FOR PESSOA COM TEA, INCLUIR ROTINAS DO CUIDADOR VINCULADO
        if owner.perfil and "tea" in owner.perfil.lower():
          accepted_links = CareLink.query.filter_by(
            pessoa_tea_id=owner.id,
            status="accepted"
          ).all()
          for link in accepted_links:
            cuidador = User.query.get(link.cuidador_id)
            if cuidador:
              routines.extend(cuidador.routines)
  
  # REMOVER DUPLICATAS MANTENDO A ORDEM
  seen = set()
  unique_routines = []
  for routine in routines:
    if routine.id not in seen:
      seen.add(routine.id)
      unique_routines.append(routine)
  
  # SERIALIZAR ROTINAS
  routines_data = [_routine_to_dict(routine) for routine in unique_routines]
  
  # ARMAZENAR NO CACHE (5 MINUTOS)
  cache.set(cache_key, routines_data, ttl=300)
  
  return jsonify(routines_data)


@api_bp.route("/routines", methods=["POST"])
@jwt_required()
def create_routine():
  user = _current_user()
  data = _get_json()
  
  # INVALIDAR CACHE DE ROTINAS
  cache.invalidate_pattern(f"routines:user:{user.id}")

  titulo = data.get("titulo", "").strip()
  lembrete = data.get("lembrete")
  pessoa_tea_id = data.get("pessoa_tea_id")  # SE CUIDADOR ESTIVER CRIANDO PARA PESSOA COM TEA

  if not titulo:
    return jsonify({"message": "Título é obrigatório."}), 400

  # Determinar o dono da rotina
  routine_owner = user
  
  # Se for cuidador e especificou pessoa_tea_id, verificar vínculo
  if pessoa_tea_id and user.perfil and "cuidador" in user.perfil.lower():
    link = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=pessoa_tea_id,
      status="accepted"
    ).first()
    
    if link:
      routine_owner = User.query.get(pessoa_tea_id)
      if not routine_owner:
        return jsonify({"message": "Pessoa com TEA não encontrada."}), 404
    else:
      return jsonify({"message": "Vínculo não encontrado ou não aceito."}), 403

  routine = Routine(user=routine_owner, titulo=titulo, lembrete=lembrete)
  db.session.add(routine)
  db.session.commit()

  return jsonify(_routine_to_dict(routine)), 201


@api_bp.route("/routines/<int:routine_id>", methods=["PUT"])
@jwt_required()
def update_routine(routine_id: int):
  user = _current_user()
  routine = Routine.query.get_or_404(routine_id)
  
  # PROFISSIONAL NÃO PODE EDITAR (MAS ADMINISTRADOR PODE)
  if _is_profissional_or_admin(user) and not _is_admin(user):
    return jsonify({"message": "Profissionais não podem editar rotinas."}), 403
  
  # VERIFICAR SE O USUÁRIO PODE EDITAR (É DONO OU ESTÁ VINCULADO)
  can_edit = routine.user_id == user.id
  
  if not can_edit:
    # VERIFICAR SE HÁ VÍNCULO ACEITO EM QUALQUER DIREÇÃO
    link_as_cuidador = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=routine.user_id,
      status="accepted"
    ).first()
    
    link_as_pessoa_tea = CareLink.query.filter_by(
      cuidador_id=routine.user_id,
      pessoa_tea_id=user.id,
      status="accepted"
    ).first()
    
    can_edit = link_as_cuidador is not None or link_as_pessoa_tea is not None
  
  if not can_edit:
    return jsonify({"message": "Você não tem permissão para editar esta rotina."}), 403
  
  data = _get_json()

  if "titulo" in data:
    routine.titulo = data["titulo"].strip() or routine.titulo
  if "lembrete" in data:
    routine.lembrete = data["lembrete"]

  db.session.commit()
  
  # INVALIDAR CACHE DE ROTINAS DO DONO E DE USUÁRIOS VINCULADOS
  cache.invalidate_pattern(f"routines:user:{routine.user_id}")
  
  return jsonify(_routine_to_dict(routine))


@api_bp.route("/routines/<int:routine_id>", methods=["DELETE"])
@jwt_required()
def delete_routine(routine_id: int):
  user = _current_user()
  routine = Routine.query.get_or_404(routine_id)
  
  # PROFISSIONAL NÃO PODE DELETAR (MAS ADMINISTRADOR PODE)
  if _is_profissional_or_admin(user) and not _is_admin(user):
    return jsonify({"message": "Profissionais não podem deletar rotinas."}), 403
  
  # VERIFICAR SE O USUÁRIO PODE DELETAR (É DONO OU ESTÁ VINCULADO)
  can_delete = routine.user_id == user.id
  
  if not can_delete:
    # VERIFICAR SE HÁ VÍNCULO ACEITO EM QUALQUER DIREÇÃO
    link_as_cuidador = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=routine.user_id,
      status="accepted"
    ).first()
    
    link_as_pessoa_tea = CareLink.query.filter_by(
      cuidador_id=routine.user_id,
      pessoa_tea_id=user.id,
      status="accepted"
    ).first()
    
    can_delete = link_as_cuidador is not None or link_as_pessoa_tea is not None
  
  if not can_delete:
    return jsonify({"message": "Você não tem permissão para deletar esta rotina."}), 403
  
  db.session.delete(routine)
  db.session.commit()
  
  # INVALIDAR CACHE DE ROTINAS DO DONO E DE USUÁRIOS VINCULADOS
  cache.invalidate_pattern(f"routines:user:{routine.user_id}")
  
  return "", 204


@api_bp.route("/routines/<int:routine_id>/steps", methods=["POST"])
@jwt_required()
def add_routine_step(routine_id: int):
  user = _current_user()
  routine = Routine.query.get_or_404(routine_id)
  
  # VERIFICAR SE O USUÁRIO PODE EDITAR (É DONO OU ESTÁ VINCULADO)
  can_edit = routine.user_id == user.id
  
  if not can_edit:
    # VERIFICAR SE HÁ VÍNCULO ACEITO EM QUALQUER DIREÇÃO
    link_as_cuidador = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=routine.user_id,
      status="accepted"
    ).first()
    
    link_as_pessoa_tea = CareLink.query.filter_by(
      cuidador_id=routine.user_id,
      pessoa_tea_id=user.id,
      status="accepted"
    ).first()
    
    can_edit = link_as_cuidador is not None or link_as_pessoa_tea is not None
  
  if not can_edit:
    return jsonify({"message": "Você não tem permissão para adicionar steps nesta rotina."}), 403
  
  data = _get_json()

  descricao = data.get("descricao", "").strip()
  duracao = data.get("duracao")
  ordem = data.get("ordem")

  if not descricao:
    return jsonify({"message": "Descrição é obrigatória."}), 400

  if ordem is None:
    ordem = len(routine.steps)

  step = RoutineStep(routine=routine, descricao=descricao, duracao=duracao, ordem=ordem)
  db.session.add(step)
  db.session.commit()
  
  # INVALIDAR CACHE DE ROTINAS
  cache.invalidate_pattern(f"routines:user:{routine.user_id}")

  return jsonify(
    {
      "id": step.id,
      "descricao": step.descricao,
      "duracao": step.duracao,
      "ordem": step.ordem,
    }
  ), 201


@api_bp.route("/routines/<int:routine_id>/steps/<int:step_id>", methods=["PUT"])
@jwt_required()
def update_routine_step(routine_id: int, step_id: int):
  user = _current_user()
  routine = Routine.query.get_or_404(routine_id)
  
  # VERIFICAR SE O USUÁRIO PODE EDITAR (É DONO OU ESTÁ VINCULADO)
  can_edit = routine.user_id == user.id
  
  if not can_edit:
    # VERIFICAR SE HÁ VÍNCULO ACEITO EM QUALQUER DIREÇÃO
    link_as_cuidador = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=routine.user_id,
      status="accepted"
    ).first()
    
    link_as_pessoa_tea = CareLink.query.filter_by(
      cuidador_id=routine.user_id,
      pessoa_tea_id=user.id,
      status="accepted"
    ).first()
    
    can_edit = link_as_cuidador is not None or link_as_pessoa_tea is not None
  
  if not can_edit:
    return jsonify({"message": "Você não tem permissão para editar steps desta rotina."}), 403
  
  step = RoutineStep.query.filter_by(id=step_id, routine_id=routine.id).first_or_404()
  data = _get_json()

  if "descricao" in data:
    nova_descricao = (data.get("descricao") or "").strip()
    if not nova_descricao:
      return jsonify({"message": "Descrição não pode ser vazia."}), 400
    step.descricao = nova_descricao

  if "duracao" in data:
    step.duracao = data.get("duracao")

  if "ordem" in data:
    step.ordem = data.get("ordem") or 0

  db.session.commit()
  
  # INVALIDAR CACHE DE ROTINAS
  cache.invalidate_pattern(f"routines:user:{routine.user_id}")

  return jsonify(
    {
      "id": step.id,
      "descricao": step.descricao,
      "duracao": step.duracao,
      "ordem": step.ordem,
    }
  )


@api_bp.route("/routines/<int:routine_id>/steps/<int:step_id>", methods=["DELETE"])
@jwt_required()
def delete_routine_step(routine_id: int, step_id: int):
  user = _current_user()
  routine = Routine.query.get_or_404(routine_id)
  
  # VERIFICAR SE O USUÁRIO PODE DELETAR (É DONO OU ESTÁ VINCULADO)
  can_delete = routine.user_id == user.id
  
  if not can_delete:
    # VERIFICAR SE HÁ VÍNCULO ACEITO EM QUALQUER DIREÇÃO
    link_as_cuidador = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=routine.user_id,
      status="accepted"
    ).first()
    
    link_as_pessoa_tea = CareLink.query.filter_by(
      cuidador_id=routine.user_id,
      pessoa_tea_id=user.id,
      status="accepted"
    ).first()
    
    can_delete = link_as_cuidador is not None or link_as_pessoa_tea is not None
  
  if not can_delete:
    return jsonify({"message": "Você não tem permissão para deletar steps desta rotina."}), 403
  
  step = RoutineStep.query.filter_by(id=step_id, routine_id=routine.id).first_or_404()

  db.session.delete(step)
  db.session.commit()
  
  # INVALIDAR CACHE DE ROTINAS
  cache.invalidate_pattern(f"routines:user:{routine.user_id}")
  
  return "", 204


@api_bp.route("/entries", methods=["GET"])
@jwt_required()
def list_entries():
  user = _current_user()
  tipo = request.args.get("tipo")
  from_str = request.args.get("from")
  to_str = request.args.get("to")
  pessoa_tea_id = request.args.get("pessoa_tea_id", type=int)

  from_date = _parse_datetime(from_str) if from_str else None
  to_date = _parse_datetime(to_str) if to_str else None

  entries = []
  
  # SE CUIDADOR ESPECIFICOU PESSOA_TEA_ID, BUSCAR ENTRIES DA PESSOA COM TEA
  if pessoa_tea_id and user.perfil and "cuidador" in user.perfil.lower():
    link = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=pessoa_tea_id,
      status="accepted"
    ).first()
    
    if not link:
      return jsonify({"message": "Vínculo não encontrado ou não aceito."}), 403
    
    pessoa_tea = User.query.get(pessoa_tea_id)
    if not pessoa_tea:
      return jsonify({"message": "Pessoa com TEA não encontrada."}), 404
    
    query = Entry.query.filter_by(user_id=pessoa_tea.id)
    if tipo:
      query = query.filter_by(tipo=tipo)
    if from_date:
      query = query.filter(Entry.timestamp >= from_date)
    if to_date:
      query = query.filter(Entry.timestamp <= to_date)
    entries = query.order_by(Entry.timestamp.desc()).all()
  
  # SE FOR PROFISSIONAL OU ADMINISTRADOR, BUSCAR ENTRIES COMPARTILHADOS
  elif _is_profissional_or_admin(user):
    shares = Share.query.filter_by(viewer_id=user.id).all()
    owner_ids = [share.owner_id for share in shares]
    
    for owner_id in owner_ids:
      owner = User.query.get(owner_id)
      if owner:
        query = Entry.query.filter_by(user_id=owner.id)
        if tipo:
          query = query.filter_by(tipo=tipo)
        if from_date:
          query = query.filter(Entry.timestamp >= from_date)
        if to_date:
          query = query.filter(Entry.timestamp <= to_date)
        owner_entries = query.order_by(Entry.timestamp.desc()).all()
        entries.extend(owner_entries)
        
        # SE O OWNER FOR CUIDADOR, INCLUIR ENTRIES DA PESSOA COM TEA VINCULADA
        if owner.perfil and "cuidador" in owner.perfil.lower():
          accepted_links = CareLink.query.filter_by(
            cuidador_id=owner.id,
            status="accepted"
          ).all()
          for link in accepted_links:
            pessoa_tea = User.query.get(link.pessoa_tea_id)
            if pessoa_tea:
              query = Entry.query.filter_by(user_id=pessoa_tea.id)
              if tipo:
                query = query.filter_by(tipo=tipo)
              if from_date:
                query = query.filter(Entry.timestamp >= from_date)
              if to_date:
                query = query.filter(Entry.timestamp <= to_date)
              tea_entries = query.order_by(Entry.timestamp.desc()).all()
              entries.extend(tea_entries)
        
        # SE O OWNER FOR PESSOA COM TEA, INCLUIR ENTRIES DO CUIDADOR VINCULADO
        if owner.perfil and "tea" in owner.perfil.lower():
          accepted_links = CareLink.query.filter_by(
            pessoa_tea_id=owner.id,
            status="accepted"
          ).all()
          for link in accepted_links:
            cuidador = User.query.get(link.cuidador_id)
            if cuidador:
              query = Entry.query.filter_by(user_id=cuidador.id)
              if tipo:
                query = query.filter_by(tipo=tipo)
              if from_date:
                query = query.filter(Entry.timestamp >= from_date)
              if to_date:
                query = query.filter(Entry.timestamp <= to_date)
              cuidador_entries = query.order_by(Entry.timestamp.desc()).all()
              entries.extend(cuidador_entries)
    
    # REMOVER DUPLICATAS E ORDENAR
    seen = set()
    unique_entries = []
    for entry in entries:
      if entry.id not in seen:
        seen.add(entry.id)
        unique_entries.append(entry)
    entries = sorted(unique_entries, key=lambda e: e.timestamp, reverse=True)
  
  else:
    # USUÁRIO NORMAL (PESSOA COM TEA OU CUIDADOR VENDO PRÓPRIO RELATÓRIO)
    query = Entry.query.filter_by(user_id=user.id)
    if tipo:
      query = query.filter_by(tipo=tipo)
    if from_date:
      query = query.filter(Entry.timestamp >= from_date)
    if to_date:
      query = query.filter(Entry.timestamp <= to_date)
    entries = query.order_by(Entry.timestamp.desc()).all()

  return jsonify([_entry_to_dict(entry) for entry in entries])


@api_bp.route("/entries", methods=["POST"])
@jwt_required()
def create_entry():
  user = _current_user()
  data = _get_json()

  tipo = data.get("tipo")
  texto = data.get("texto")

  if not tipo or not texto:
    return jsonify({"message": "Tipo e texto são obrigatórios."}), 400

  entry = Entry(
    user=user,
    tipo=tipo,
    texto=texto,
    midia_url=data.get("midia_url"),
  )

  tags = data.get("tags")
  if isinstance(tags, list):
    entry.set_tags(tags)
  elif isinstance(tags, str):
    entry.set_tags(tags.split(","))

  timestamp = data.get("timestamp")
  if timestamp:
    entry.timestamp = _parse_datetime(timestamp, default=datetime.utcnow())

  db.session.add(entry)
  db.session.commit()

  return jsonify(_entry_to_dict(entry)), 201


@api_bp.route("/boards", methods=["GET"])
@jwt_required()
def list_boards():
  user = _current_user()
  boards = Board.query.filter_by(user_id=user.id).all()
  return jsonify([_board_to_dict(board) for board in boards])


@api_bp.route("/boards", methods=["POST"])
@jwt_required()
def create_board():
  user = _current_user()
  data = _get_json()
  nome = data.get("nome", "").strip()
  if not nome:
    return jsonify({"message": "Nome é obrigatório."}), 400

  board = Board(user=user, nome=nome)
  db.session.add(board)
  db.session.commit()

  return jsonify(_board_to_dict(board)), 201


@api_bp.route("/boards/<int:board_id>/items", methods=["POST"])
@jwt_required()
def add_board_item(board_id: int):
  user = _current_user()
  board = Board.query.filter_by(id=board_id, user_id=user.id).first_or_404()
  data = _get_json()
  texto = data.get("texto", "").strip()

  if not texto:
    return jsonify({"message": "Texto é obrigatório."}), 400

  emoji = data.get("emoji")
  categoria = data.get("categoria")

  item = BoardItem(
    board=board,
    texto=texto,
    img_url=data.get("img_url"),
    audio_url=data.get("audio_url"),
    emoji=emoji if emoji else None,
    categoria=categoria if categoria else None,
  )
  db.session.add(item)
  db.session.commit()

  return jsonify(_board_item_to_dict(item)), 201


@api_bp.route("/boards/<int:board_id>/items/<int:item_id>", methods=["PUT"])
@jwt_required()
def update_board_item(board_id: int, item_id: int):
  user = _current_user()
  board = Board.query.filter_by(id=board_id, user_id=user.id).first_or_404()
  item = BoardItem.query.filter_by(id=item_id, board_id=board.id).first_or_404()
  data = _get_json()

  if "texto" in data:
    novo_texto = (data.get("texto") or "").strip()
    if not novo_texto:
      return jsonify({"message": "Texto não pode ser vazio."}), 400
    item.texto = novo_texto

  if "emoji" in data:
    item.emoji = (data.get("emoji") or None)

  if "categoria" in data:
    item.categoria = (data.get("categoria") or None)

  if "img_url" in data:
    item.img_url = data.get("img_url")

  if "audio_url" in data:
    item.audio_url = data.get("audio_url")

  db.session.commit()
  return jsonify(_board_item_to_dict(item))


@api_bp.route("/boards/<int:board_id>/items/<int:item_id>", methods=["DELETE"])
@jwt_required()
def delete_board_item(board_id: int, item_id: int):
  user = _current_user()
  board = Board.query.filter_by(id=board_id, user_id=user.id).first_or_404()
  item = BoardItem.query.filter_by(id=item_id, board_id=board.id).first_or_404()

  db.session.delete(item)
  db.session.commit()
  return "", 204


@api_bp.route("/reports/weekly", methods=["GET"])
@jwt_required()
def weekly_report():
  user = _current_user()
  from_str = request.args.get("from")
  to_str = request.args.get("to")
  pessoa_tea_id = request.args.get("pessoa_tea_id", type=int)  # PARA CUIDADOR VER RELATÓRIO ESPECÍFICO

  default_to = datetime.utcnow()
  default_from = default_to - timedelta(days=7)

  start = _parse_datetime(from_str, default=default_from)
  end = _parse_datetime(to_str, default=default_to)

  # DETERMINAR QUAL USUÁRIO GERAR O RELATÓRIO
  report_user = user
  
  # SE FOR CUIDADOR E ESPECIFICOU PESSOA_TEA_ID, VERIFICAR VÍNCULO
  if pessoa_tea_id and user.perfil and "cuidador" in user.perfil.lower():
    link = CareLink.query.filter_by(
      cuidador_id=user.id,
      pessoa_tea_id=pessoa_tea_id,
      status="accepted"
    ).first()
    
    if link:
      report_user = User.query.get(pessoa_tea_id)
      if not report_user:
        return jsonify({"message": "Pessoa com TEA não encontrada."}), 404
    else:
      return jsonify({"message": "Vínculo não encontrado ou não aceito."}), 403

  entries = (
    Entry.query.filter_by(user_id=report_user.id)
    .filter(Entry.timestamp >= start, Entry.timestamp <= end)
    .all()
  )

  routines = Routine.query.filter_by(user_id=report_user.id).all()

  entry_counter = Counter(entry.tipo for entry in entries)

  payload = {
    "user_id": report_user.id,
    "user_name": report_user.nome_completo,
    "interval": {"from": start.isoformat(), "to": end.isoformat()},
    "entries_total": len(entries),
    "entries_by_type": dict(entry_counter),
    "routines_total": len(routines),
    "steps_total": sum(len(routine.steps) for routine in routines),
  }
  return jsonify(payload)


@api_bp.route("/reports/export", methods=["POST"])
@jwt_required()
def export_report():
  user = _current_user()
  data = _get_json()
  report_type = data.get("tipo", "weekly")

  export_id = uuid4()
  fake_link = f"https://example.com/reports/{user.id}/{export_id}.{ 'pdf' if report_type == 'pdf' else 'csv'}"

  return jsonify(
    {"message": "Exportação iniciada. Link disponível por tempo limitado.", "url": fake_link}
  )


@api_bp.route("/shares", methods=["POST"])
@jwt_required()
def create_share():
  owner = _current_user()
  data = _get_json()

  viewer_email = data.get("viewer_email", "").strip().lower()
  escopo = data.get("escopo", "read")
  expira_em = _parse_datetime(data.get("expira_em")) if data.get("expira_em") else None

  if not viewer_email:
    return jsonify({"message": "viewer_email é obrigatório."}), 400

  # BUSCAR O VIEWER PELO EMAIL
  viewer = User.query.filter_by(email=viewer_email).first()
  if not viewer:
    return jsonify({"message": "Email não encontrado."}), 404

  # VERIFICAR SE O VIEWER É UM PROFISSIONAL OU ADMINISTRADOR
  if not viewer.perfil or (not _is_profissional_or_admin(viewer)):
    return jsonify({"message": "O email informado não pertence a um profissional ou administrador."}), 400

  # VERIFICAR SE JÁ EXISTE UM SHARE ATIVO
  existing_share = Share.query.filter_by(
    owner_id=owner.id,
    viewer_email=viewer_email
  ).first()
  
  if existing_share:
    return jsonify({"message": "Compartilhamento já existe para este profissional."}), 400

  share = Share(
    owner=owner,
    viewer=viewer,
    viewer_email=viewer_email,
    escopo=escopo,
    expira_em=expira_em,
  )
  db.session.add(share)
  db.session.commit()
  
  # INVALIDAR CACHE DE SHARES
  cache.invalidate_pattern(f"shares:user:{owner.id}")
  if share.viewer_id:
    cache.invalidate_pattern(f"shares:user:{share.viewer_id}")

  return jsonify(
    {
      "id": share.id,
      "viewer_email": share.viewer_email,
      "viewer_id": share.viewer_id,
      "escopo": share.escopo,
      "expira_em": share.expira_em.isoformat() if share.expira_em else None,
    }
  ), 201


@api_bp.route("/shares", methods=["GET"])
@jwt_required()
def list_shares():
  user = _current_user()
  
  # TENTAR BUSCAR DO CACHE
  cache_key = f"shares:user:{user.id}"
  cached_shares = cache.get(cache_key)
  if cached_shares is not None:
    return jsonify(cached_shares), 200
  
  # SE FOR PROFISSIONAL OU ADMINISTRADOR, RETORNAR SHARES RECEBIDOS (ONDE É VIEWER)
  # SE FOR CUIDADOR OU PESSOA COM TEA, RETORNAR SHARES CRIADOS (ONDE É OWNER)
  if _is_profissional_or_admin(user):
    shares = Share.query.filter_by(viewer_id=user.id).all()
    result = []
    for share in shares:
      # VERIFICAR SE HÁ NOTIFICAÇÃO PENDENTE PARA ESTE SHARE
      # SE HOUVER, NÃO RETORNAR (AINDA NÃO FOI ACEITO)
      pending_notification = Notification.query.filter_by(
        share_id=share.id,
        tipo="share_request",
        lida=False
      ).first()
      
      if pending_notification:
        continue  # PULAR SHARES PENDENTES
      
      owner = User.query.get(share.owner_id)
      result.append({
        "id": share.id,
        "owner_id": share.owner_id,
        "owner_nome": owner.nome_completo if owner else None,
        "owner_email": owner.email if owner else None,
        "owner_perfil": owner.perfil if owner else None,
        "escopo": share.escopo,
        "expira_em": share.expira_em.isoformat() if share.expira_em else None,
        "created_at": share.created_at.isoformat(),
      })
  else:
    shares = Share.query.filter_by(owner_id=user.id).all()
    result = []
    for share in shares:
      viewer = User.query.get(share.viewer_id) if share.viewer_id else None
      result.append({
        "id": share.id,
        "viewer_id": share.viewer_id,
        "viewer_email": share.viewer_email,
        "viewer_nome": viewer.nome_completo if viewer else None,
        "escopo": share.escopo,
        "expira_em": share.expira_em.isoformat() if share.expira_em else None,
        "created_at": share.created_at.isoformat(),
      })
  
  # ARMAZENAR NO CACHE (5 MINUTOS)
  cache.set(cache_key, result, ttl=300)
  
  return jsonify(result), 200


@api_bp.route("/shares/request", methods=["POST"])
@jwt_required()
def request_share():
  """Profissional solicita acesso aos relatórios e rotinas de um cuidador ou pessoa com TEA"""
  try:
    viewer = _current_user()  # O profissional que está solicitando
    data = _get_json()
    
    owner_email = data.get("owner_email", "").strip().lower()
    
    if not owner_email:
      return jsonify({"message": "owner_email é obrigatório."}), 400
    
    # VERIFICAR SE O USUÁRIO É UM PROFISSIONAL OU ADMINISTRADOR
    if not viewer.perfil or (not _is_profissional_or_admin(viewer)):
      return jsonify({"message": "Apenas profissionais podem solicitar acesso."}), 403
    
    # BUSCAR O OWNER PELO EMAIL
    owner = User.query.filter_by(email=owner_email).first()
    if not owner:
      return jsonify({"message": "Email não encontrado."}), 404
    
    # VERIFICAR SE O OWNER É CUIDADOR OU PESSOA COM TEA
    owner_perfil = owner.perfil.lower() if owner.perfil else ""
    if "cuidador" not in owner_perfil and "tea" not in owner_perfil:
      return jsonify({"message": "O email informado não pertence a um cuidador ou pessoa com TEA."}), 400
    
    # VERIFICAR SE JÁ EXISTE UM SHARE ATIVO (JÁ ACEITO)
    existing_share = Share.query.filter_by(
      owner_id=owner.id,
      viewer_id=viewer.id
    ).first()
    
    if existing_share:
      # SHARE JÁ EXISTE, SIGNIFICA QUE JÁ FOI ACEITO
      return jsonify({"message": "Você já tem acesso aos relatórios e rotinas desta conta."}), 400
    
    # VERIFICAR SE JÁ EXISTE UMA NOTIFICAÇÃO PENDENTE
    existing_notification = Notification.query.filter_by(
      user_id=owner.id,
      tipo="share_request",
      lida=False
    ).all()
    
    # VERIFICAR SE ALGUMA NOTIFICAÇÃO PENDENTE É PARA ESTE PROFISSIONAL
    for notif in existing_notification:
      mensagem = notif.mensagem or ""
      viewer_match = re.search(r'\|\|\|VIEWER_ID:(\d+)', mensagem)
      if viewer_match and int(viewer_match.group(1)) == viewer.id:
        return jsonify({"message": "Já existe uma solicitação pendente para este acesso."}), 400
      # TAMBÉM VERIFICAR POR EMAIL
      if viewer.email in mensagem:
        return jsonify({"message": "Já existe uma solicitação pendente para este acesso."}), 400
    
    # NÃO CRIAR O SHARE AINDA - SÓ CRIAR QUANDO FOR ACEITO
    # CRIAR APENAS A NOTIFICAÇÃO PARA O OWNER
    # ARMAZENAR viewer_id E owner_id EM UM CAMPO SEPARADO (data JSON) OU NA MENSAGEM MAS OCULTO
    # VAMOS USAR UM FORMATO QUE PODE SER EXTRAÍDO MAS NÃO É VISÍVEL NA UI
    mensagem_visivel = f"{viewer.nome_completo} ({viewer.email}) deseja acessar seus relatórios e rotinas."
    # ARMAZENAR IDs NO FINAL DA MENSAGEM COM UM SEPARADOR ESPECIAL QUE SERÁ REMOVIDO NA UI
    mensagem_completa = f"{mensagem_visivel}|||VIEWER_ID:{viewer.id}|||OWNER_ID:{owner.id}"
    
    notification_data = {
      "user_id": owner.id,
      "tipo": "share_request",
      "titulo": "Solicitação de acesso",
      "mensagem": mensagem_completa,
    }
    
    notification = Notification(**notification_data)
    
    db.session.add(notification)
    db.session.commit()
    
    # ARMAZENAR INFORMAÇÕES DO SHARE PENDENTE EM UM DICIONÁRIO TEMPORÁRIO
    # OU MELHOR: CRIAR UMA TABELA DE SHARES PENDENTES OU USAR A MENSAGEM
    # POR ENQUANTO, VAMOS ARMAZENAR viewer_id E owner_id NA MENSAGEM DE FORMA ESTRUTURADA
    
    # INVALIDAR CACHE
    cache.invalidate_pattern(f"notifications:user:{owner.id}")
    
    return jsonify({
      "message": "Solicitação enviada com sucesso. Aguarde a aprovação do cuidador ou pessoa com TEA.",
      "notification_id": notification.id,
      "viewer_id": viewer.id,
      "owner_id": owner.id
    }), 201
  except Exception as e:
    db.session.rollback()
    import traceback
    error_trace = traceback.format_exc()
    print(f"ERRO em request_share: {error_trace}")
    return jsonify({
      "message": f"Erro ao processar solicitação: {str(e)}",
      "error": str(e)
    }), 500


@api_bp.route("/shares/<int:share_id>/respond", methods=["POST"])
@jwt_required()
def respond_share(share_id: int):
  """Cuidador ou pessoa com TEA aceita ou rejeita solicitação de acesso do profissional"""
  try:
    user = _current_user()
    data = _get_json()
    accept = data.get("accept", False)
    
    # share_id AGORA É O ID DA NOTIFICAÇÃO, NÃO DO SHARE
    # O SHARE SÓ SERÁ CRIADO SE FOR ACEITO
    # BUSCAR A NOTIFICAÇÃO PELO ID (QUE FOI PASSADO COMO share_id)
    notification = Notification.query.get(share_id)
    
    if not notification:
      return jsonify({"message": "Notificação não encontrada."}), 404
    
    # VERIFICAR SE O USUÁRIO É O DONO DA NOTIFICAÇÃO
    if notification.user_id != user.id:
      return jsonify({"message": "Você não tem permissão para responder esta solicitação."}), 403
    
    # VERIFICAR SE É DO TIPO CORRETO
    if notification.tipo != "share_request":
      return jsonify({"message": "Esta notificação não é uma solicitação de acesso."}), 400
    
    # VERIFICAR SE JÁ FOI RESPONDIDA (VERIFICANDO SE EXISTE SHARE)
    # EXTRAIR viewer_id DA MENSAGEM PARA VERIFICAR SE JÁ EXISTE SHARE
    mensagem = notification.mensagem or ""
    viewer_match = re.search(r'\|\|\|VIEWER_ID:(\d+)', mensagem)
    viewer_id_from_notif = None
    
    if viewer_match:
      viewer_id_from_notif = int(viewer_match.group(1))
      # VERIFICAR SE JÁ EXISTE UM SHARE (FOI ACEITA)
      existing_share = Share.query.filter_by(
        owner_id=user.id,
        viewer_id=viewer_id_from_notif
      ).first()
      if existing_share:
        # SE EXISTE SHARE, SIGNIFICA QUE JÁ FOI ACEITA
        # MARCAR NOTIFICAÇÃO COMO LIDA SE AINDA NÃO ESTIVER
        if not notification.lida:
          notification.lida = True
          db.session.commit()
        return jsonify({"message": "Esta solicitação já foi aceita anteriormente."}), 400
    
    
    if accept:
      # ACEITAR: CRIAR O SHARE AGORA (NÃO EXISTIA ANTES)
      # USAR O viewer_id JÁ EXTRAÍDO ANTERIORMENTE
      viewer_id = viewer_id_from_notif
      owner_id = user.id
      
      # SE NÃO CONSEGUIMOS EXTRAIR ANTES, TENTAR NOVAMENTE
      if not viewer_id:
        # FORMATO: "[VIEWER_ID:123][OWNER_ID:456]"
        viewer_match = re.search(r'\[VIEWER_ID:(\d+)\]', mensagem)
        if viewer_match:
          viewer_id = int(viewer_match.group(1))
        else:
          # TENTAR BUSCAR POR EMAIL NA MENSAGEM
          # A MENSAGEM TEM O FORMATO: "{nome} ({email}) deseja acessar..."
          email_match = re.search(r'\(([^)]+@[^)]+)\)', mensagem)
          if email_match:
            viewer_email = email_match.group(1)
            viewer_user = User.query.filter_by(email=viewer_email).first()
            if viewer_user:
              viewer_id = viewer_user.id
      
      if not viewer_id:
        return jsonify({"message": "Não foi possível identificar o profissional na solicitação."}), 400
      
      # VERIFICAR SE JÁ EXISTE UM SHARE
      existing_share = Share.query.filter_by(
        owner_id=owner_id,
        viewer_id=viewer_id
      ).first()
      
      if existing_share:
        # SHARE JÁ EXISTE, APENAS MARCAR NOTIFICAÇÃO COMO LIDA
        notification.lida = True
        db.session.commit()
      else:
        # CRIAR O SHARE AGORA QUE FOI ACEITO
        viewer_user = User.query.get(viewer_id)
        if not viewer_user:
          return jsonify({"message": "Profissional não encontrado."}), 404
        
        new_share = Share(
          owner_id=owner_id,
          viewer_id=viewer_id,
          viewer_email=viewer_user.email,
          escopo="read",
          expira_em=None,
        )
        db.session.add(new_share)
        db.session.flush()
        
        # MARCAR NOTIFICAÇÃO COMO LIDA E VINCULAR AO SHARE
        notification.lida = True
        try:
          inspector = sqlalchemy_inspect(Notification)
          has_share_id = 'share_id' in [col.name for col in inspector.columns]
          if has_share_id:
            notification.share_id = new_share.id
        except Exception:
          pass
        
        db.session.commit()
        
        # CRIAR NOTIFICAÇÃO PARA O PROFISSIONAL
        notification_data = {
          "user_id": viewer_id,
          "tipo": "share_accepted",
          "titulo": "Acesso concedido",
          "mensagem": f"{user.nome_completo} aceitou sua solicitação de acesso aos relatórios e rotinas.",
        }
        
        try:
          inspector = sqlalchemy_inspect(Notification)
          has_share_id = 'share_id' in [col.name for col in inspector.columns]
          if has_share_id:
            notification_data["share_id"] = new_share.id
        except Exception:
          pass
        
        accept_notification = Notification(**notification_data)
        db.session.add(accept_notification)
        db.session.commit()
        
        # INVALIDAR CACHE
        cache.invalidate_pattern(f"shares:user:{owner_id}")
        cache.invalidate_pattern(f"shares:user:{viewer_id}")
        cache.invalidate_pattern(f"notifications:user:{viewer_id}")
        
        return jsonify({
          "message": "Solicitação aceita com sucesso. O profissional agora tem acesso aos seus relatórios e rotinas.",
          "status": "accepted",
          "share_id": new_share.id
        }), 200
    else:
      # REJEITAR: APENAS MARCAR NOTIFICAÇÃO COMO LIDA (NÃO CRIAR SHARE)
      # USAR O viewer_id JÁ EXTRAÍDO ANTERIORMENTE
      viewer_id = viewer_id_from_notif
      
      # SE NÃO CONSEGUIMOS EXTRAIR ANTES, TENTAR NOVAMENTE
      if not viewer_id:
        viewer_match = re.search(r'\[VIEWER_ID:(\d+)\]', mensagem)
        if viewer_match:
          viewer_id = int(viewer_match.group(1))
        else:
          # TENTAR EXTRAIR EMAIL
          email_match = re.search(r'\(([^)]+@[^)]+)\)', mensagem)
          if email_match:
            viewer_email = email_match.group(1)
            viewer_user = User.query.filter_by(email=viewer_email).first()
            if viewer_user:
              viewer_id = viewer_user.id
      
      notification.lida = True
      db.session.commit()
      
      # CRIAR NOTIFICAÇÃO PARA O PROFISSIONAL
      if viewer_id:
        reject_notification = Notification(
          user_id=viewer_id,
          tipo="share_rejected",
          titulo="Acesso negado",
          mensagem=f"{user.nome_completo} rejeitou sua solicitação de acesso aos relatórios e rotinas.",
        )
        db.session.add(reject_notification)
        db.session.commit()
        
        # INVALIDAR CACHE
        cache.invalidate_pattern(f"notifications:user:{viewer_id}")
      
      return jsonify({
        "message": "Solicitação rejeitada.",
        "status": "rejected"
      }), 200
  except Exception as e:
    db.session.rollback()
    import traceback
    error_trace = traceback.format_exc()
    print(f"ERRO em respond_share: {error_trace}")
    return jsonify({
      "message": f"Erro ao processar resposta: {str(e)}",
      "error": str(e)
    }), 500


@api_bp.route("/shares/<int:share_id>", methods=["DELETE"])
@jwt_required()
def delete_share(share_id: int):
  user = _current_user()
  share = Share.query.get_or_404(share_id)
  
  # VERIFICAR SE O USUÁRIO É O OWNER OU O VIEWER (PROFISSIONAL PODE REMOVER SEU PRÓPRIO ACESSO)
  if share.owner_id != user.id and (share.viewer_id != user.id):
    return jsonify({"message": "Você não tem permissão para remover este compartilhamento."}), 403
  
  db.session.delete(share)
  db.session.commit()
  
  # INVALIDAR CACHE DE SHARES
  cache.invalidate_pattern(f"shares:user:{share.owner_id}")
  if share.viewer_id:
    cache.invalidate_pattern(f"shares:user:{share.viewer_id}")
  
  return "", 204


# ========== VÍNCULO DE CUIDADO ==========

@api_bp.route("/care-links/request", methods=["POST"])
@jwt_required()
def request_care_link():
  cuidador = _current_user()
  
  # VERIFICAR SE É CUIDADOR
  if not cuidador.perfil or "cuidador" not in cuidador.perfil.lower():
    return jsonify({"message": "Apenas cuidadores podem solicitar vínculo."}), 403
  
  data = _get_json()
  pessoa_tea_email = data.get("pessoa_tea_email", "").strip().lower()
  
  if not pessoa_tea_email:
    return jsonify({"message": "Email da Pessoa com TEA é obrigatório."}), 400
  
  # BUSCAR PESSOA COM TEA PELO EMAIL
  pessoa_tea = User.query.filter_by(email=pessoa_tea_email).first()
  if not pessoa_tea:
    return jsonify({"message": "Email não encontrado."}), 404
  
  # VERIFICAR SE É REALMENTE PESSOA COM TEA
  if not pessoa_tea.perfil or "tea" not in pessoa_tea.perfil.lower():
    return jsonify({"message": "O email informado não pertence a uma Pessoa com TEA."}), 400
  
  # VERIFICAR SE JÁ EXISTE VÍNCULO
  existing_link = CareLink.query.filter_by(
    cuidador_id=cuidador.id,
    pessoa_tea_id=pessoa_tea.id
  ).first()
  
  if existing_link:
    if existing_link.status == "accepted":
      return jsonify({"message": "Vínculo já existe e está aceito."}), 400
    elif existing_link.status == "pending":
      return jsonify({"message": "Solicitação já existe e está pendente."}), 400
  
  # CRIAR SOLICITAÇÃO
  care_link = CareLink(
    cuidador_id=cuidador.id,
    pessoa_tea_id=pessoa_tea.id,
    status="pending"
  )
  db.session.add(care_link)
  db.session.flush()  # GARANTIR QUE O ID SEJA GERADO ANTES DE CRIAR A NOTIFICAÇÃO
  
  # INVALIDAR CACHE DE CARE_LINKS
  cache.invalidate_pattern(f"care_links:user:{cuidador.id}")
  cache.invalidate_pattern(f"care_links:user:{pessoa_tea.id}")
  
  # CRIAR NOTIFICAÇÃO PARA A PESSOA COM TEA
  notification = Notification(
    user_id=pessoa_tea.id,
    tipo="care_link_request",
    titulo="Nova solicitação de vínculo",
    mensagem=f"{cuidador.nome_completo} deseja se vincular como seu cuidador.",
    care_link_id=care_link.id
  )
  db.session.add(notification)
  
  db.session.commit()
  
  return jsonify({
    "message": "Solicitação enviada com sucesso.",
    "care_link_id": care_link.id
  }), 201


@api_bp.route("/care-links/<int:care_link_id>/respond", methods=["POST"])
@jwt_required()
def respond_care_link(care_link_id: int):
  user = _current_user()
  data = _get_json()
  accept = data.get("accept", False)
  
  care_link = CareLink.query.get_or_404(care_link_id)
  
  # VERIFICAR SE O USUÁRIO É A PESSOA COM TEA DO VÍNCULO
  if care_link.pessoa_tea_id != user.id:
    return jsonify({"message": "Você não tem permissão para responder esta solicitação."}), 403
  
  if care_link.status != "pending":
    return jsonify({"message": "Esta solicitação já foi respondida."}), 400
  
  # ATUALIZAR STATUS
  care_link.status = "accepted" if accept else "rejected"
  db.session.commit()
  
  # INVALIDAR CACHE DE CARE_LINKS
  cache.invalidate_pattern(f"care_links:user:{care_link.cuidador_id}")
  cache.invalidate_pattern(f"care_links:user:{care_link.pessoa_tea_id}")
  # TAMBÉM INVALIDAR CACHE DE ROTINAS, POIS PODEM TER MUDADO
  cache.invalidate_pattern(f"routines:user:{care_link.cuidador_id}")
  cache.invalidate_pattern(f"routines:user:{care_link.pessoa_tea_id}")
  
  # CRIAR NOTIFICAÇÃO PARA O CUIDADOR
  notification = Notification(
    user_id=care_link.cuidador_id,
    tipo="care_link_accepted" if accept else "care_link_rejected",
    titulo="Resposta à solicitação de vínculo",
    mensagem=f"{user.nome_completo} {'aceitou' if accept else 'rejeitou'} sua solicitação de vínculo.",
    care_link_id=care_link.id
  )
  db.session.add(notification)
  db.session.commit()
  
  return jsonify({
    "message": f"Solicitação {'aceita' if accept else 'rejeitada'} com sucesso.",
    "status": care_link.status
  })


@api_bp.route("/care-links/<int:care_link_id>", methods=["DELETE"])
@jwt_required()
def delete_care_link(care_link_id: int):
  try:
    user = _current_user()
    care_link = CareLink.query.get(care_link_id)
    
    if not care_link:
      return jsonify({"message": "Vínculo não encontrado."}), 404
    
    # VERIFICAR SE O USUÁRIO É O CUIDADOR OU A PESSOA COM TEA DO VÍNCULO
    is_cuidador = care_link.cuidador_id == user.id
    is_pessoa_tea = care_link.pessoa_tea_id == user.id
    
    if not (is_cuidador or is_pessoa_tea):
      return jsonify({"message": "Você não tem permissão para remover este vínculo."}), 403
    
    # SALVAR INFORMAÇÕES ANTES DE DELETAR
    other_user_id = care_link.pessoa_tea_id if is_cuidador else care_link.cuidador_id
    user_nome = user.nome_completo
    
    # ATUALIZAR TODAS AS NOTIFICAÇÕES EXISTENTES QUE REFERENCIAM ESTE CARE_LINK_ID PARA NULL
    # ISSO EVITA PROBLEMAS COM FOREIGN KEY CONSTRAINTS
    Notification.query.filter_by(care_link_id=care_link_id).update(
      {"care_link_id": None}
    )
    
    # CRIAR NOTIFICAÇÃO PARA O OUTRO USUÁRIO (SEM CARE_LINK_ID, POIS SERÁ DELETADO)
    notification = Notification(
      user_id=other_user_id,
      tipo="care_link_removed",
      titulo="Vínculo removido",
      mensagem=f"{user_nome} removeu o vínculo de cuidado.",
      care_link_id=None  # Não referenciar o vínculo que será deletado
    )
    db.session.add(notification)
    
    # REMOVER VÍNCULO
    db.session.delete(care_link)
    db.session.commit()
    
    # INVALIDAR CACHE DE CARE_LINKS E ROTINAS
    cache.invalidate_pattern(f"care_links:user:{care_link.cuidador_id}")
    cache.invalidate_pattern(f"care_links:user:{care_link.pessoa_tea_id}")
    cache.invalidate_pattern(f"routines:user:{care_link.cuidador_id}")
    cache.invalidate_pattern(f"routines:user:{care_link.pessoa_tea_id}")
    
    return jsonify({"message": "Vínculo removido com sucesso."}), 200
  except Exception as e:
    db.session.rollback()
    return jsonify({"message": f"Erro ao remover vínculo: {str(e)}"}), 400


@api_bp.route("/care-links", methods=["GET"])
@jwt_required()
def list_care_links():
  user = _current_user()
  
  # TENTAR BUSCAR DO CACHE
  cache_key = f"care_links:user:{user.id}"
  cached_links = cache.get(cache_key)
  if cached_links is not None:
    return jsonify(cached_links), 200
  
  # SE FOR CUIDADOR, RETORNAR VÍNCULOS ONDE É CUIDADOR
  # SE FOR PESSOA COM TEA, RETORNAR VÍNCULOS ONDE É PESSOA COM TEA
  if user.perfil and "cuidador" in user.perfil.lower():
    links = CareLink.query.filter_by(cuidador_id=user.id).all()
  elif user.perfil and "tea" in user.perfil.lower():
    links = CareLink.query.filter_by(pessoa_tea_id=user.id).all()
  else:
    links = []
  
  result = []
  for link in links:
    if user.perfil and "cuidador" in user.perfil.lower():
      pessoa_tea = User.query.get(link.pessoa_tea_id)
      result.append({
        "id": link.id,
        "pessoa_tea_id": link.pessoa_tea_id,
        "pessoa_tea_nome": pessoa_tea.nome_completo if pessoa_tea else None,
        "pessoa_tea_email": pessoa_tea.email if pessoa_tea else None,
        "status": link.status,
        "created_at": link.created_at.isoformat(),
      })
    else:
      cuidador = User.query.get(link.cuidador_id)
      result.append({
        "id": link.id,
        "cuidador_id": link.cuidador_id,
        "cuidador_nome": cuidador.nome_completo if cuidador else None,
        "cuidador_email": cuidador.email if cuidador else None,
        "status": link.status,
        "created_at": link.created_at.isoformat(),
      })
  
  # ARMAZENAR NO CACHE (5 MINUTOS)
  cache.set(cache_key, result, ttl=300)
  
  return jsonify(result), 200


# ========== NOTIFICAÇÕES ==========

@api_bp.route("/notifications", methods=["GET"])
@jwt_required()
def list_notifications():
  user = _current_user()
  notifications = Notification.query.filter_by(user_id=user.id).order_by(Notification.created_at.desc()).all()
  
  result = []
  for notif in notifications:
    result.append({
      "id": notif.id,
      "tipo": notif.tipo,
      "titulo": notif.titulo,
      "mensagem": notif.mensagem,
      "lida": notif.lida,
      "care_link_id": notif.care_link_id,
      "share_id": notif.share_id,
      "created_at": notif.created_at.isoformat(),
    })
  
  return jsonify(result), 200


@api_bp.route("/notifications/<int:notification_id>/read", methods=["PUT"])
@jwt_required()
def mark_notification_read(notification_id: int):
  user = _current_user()
  notification = Notification.query.get_or_404(notification_id)
  
  if notification.user_id != user.id:
    return jsonify({"message": "Você não tem permissão para marcar esta notificação."}), 403
  
  notification.lida = True
  db.session.commit()
  
  return jsonify({"message": "Notificação marcada como lida."}), 200


@api_bp.route("/help-request", methods=["POST"])
@jwt_required()
def request_help():
  """Cria notificações para cuidadores e profissionais vinculados quando uma Pessoa com TEA precisa de ajuda"""
  user = _current_user()
  data = _get_json()
  
  # VERIFICAR SE O USUÁRIO É UMA PESSOA COM TEA
  if not user.perfil or "tea" not in user.perfil.lower():
    return jsonify({"message": "Esta funcionalidade é apenas para Pessoa com TEA."}), 403
  
  # BUSCAR CUIDADORES VINCULADOS (CARE LINKS ACEITOS)
  care_links = CareLink.query.filter_by(
    pessoa_tea_id=user.id,
    status="accepted"
  ).all()
  
  # BUSCAR PROFISSIONAIS VINCULADOS (SHARES ONDE O USUÁRIO É OWNER)
  shares = Share.query.filter_by(owner_id=user.id).all()
  
  notifications_created = 0
  
  # CRIAR NOTIFICAÇÕES PARA CUIDADORES
  for link in care_links:
    cuidador = User.query.get(link.cuidador_id)
    if cuidador:
      notification = Notification(
        user_id=cuidador.id,
        tipo="help_request",
        titulo=f"{user.nome_completo} precisa de ajuda",
        mensagem=f"{user.nome_completo} está usando o botão de calma rápida e pode precisar de seu apoio.",
      )
      db.session.add(notification)
      notifications_created += 1
  
  # CRIAR NOTIFICAÇÕES PARA PROFISSIONAIS
  for share in shares:
    if share.viewer_id:
      profissional = User.query.get(share.viewer_id)
      if profissional:
        notification = Notification(
          user_id=profissional.id,
          tipo="help_request",
          titulo=f"{user.nome_completo} precisa de ajuda",
          mensagem=f"{user.nome_completo} está usando o botão de calma rápida e pode precisar de seu apoio.",
        )
        db.session.add(notification)
        notifications_created += 1
  
  db.session.commit()
  
  return jsonify({
    "message": "Notificações enviadas com sucesso.",
    "notifications_sent": notifications_created,
  }), 201

