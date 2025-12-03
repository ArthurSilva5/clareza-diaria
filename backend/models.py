from datetime import datetime
from typing import List, Optional

from werkzeug.security import check_password_hash, generate_password_hash

from .extensions import db


class BaseModel(db.Model):
    __abstract__ = True

    id = db.Column(db.Integer, primary_key=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )


class User(BaseModel):
    __tablename__ = "users"

    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(50), nullable=False, default="viewer")
    nome_completo = db.Column(db.String(255), nullable=False)
    perfil = db.Column(db.String(100))
    preferencias_sensoriais = db.Column(db.Text)

    routines = db.relationship("Routine", back_populates="user", cascade="all, delete-orphan")
    entries = db.relationship("Entry", back_populates="user", cascade="all, delete-orphan")
    boards = db.relationship("Board", back_populates="user", cascade="all, delete-orphan")
    shares_owned = db.relationship(
        "Share",
        foreign_keys="Share.owner_id",
        back_populates="owner",
        cascade="all, delete-orphan",
    )
    shares_received = db.relationship(
        "Share",
        foreign_keys="Share.viewer_id",
        back_populates="viewer",
        cascade="all, delete-orphan",
    )
    care_links_as_cuidador = db.relationship(
        "CareLink",
        foreign_keys="CareLink.cuidador_id",
        back_populates="cuidador",
        cascade="all, delete-orphan",
    )
    care_links_as_pessoa_tea = db.relationship(
        "CareLink",
        foreign_keys="CareLink.pessoa_tea_id",
        back_populates="pessoa_tea",
        cascade="all, delete-orphan",
    )
    notifications = db.relationship(
        "Notification",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="Notification.created_at.desc()",
    )

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)


class Routine(BaseModel):
    __tablename__ = "routines"

    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    titulo = db.Column(db.String(255), nullable=False)
    lembrete = db.Column(db.String(120))

    user = db.relationship("User", back_populates="routines")
    steps = db.relationship(
        "RoutineStep",
        back_populates="routine",
        cascade="all, delete-orphan",
        order_by="RoutineStep.ordem",
    )


class RoutineStep(BaseModel):
    __tablename__ = "routine_steps"

    routine_id = db.Column(db.Integer, db.ForeignKey("routines.id"), nullable=False, index=True)
    descricao = db.Column(db.String(500), nullable=False)
    duracao = db.Column(db.Integer)
    ordem = db.Column(db.Integer, nullable=False, default=0)

    routine = db.relationship("Routine", back_populates="steps")


class Entry(BaseModel):
    __tablename__ = "entries"

    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    tipo = db.Column(db.String(50), nullable=False)
    texto = db.Column(db.Text, nullable=False)
    midia_url = db.Column(db.String(255))
    tags = db.Column(db.Text)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    user = db.relationship("User", back_populates="entries")

    def tags_list(self) -> List[str]:
        if not self.tags:
            return []
        return [tag.strip() for tag in self.tags.split(",") if tag.strip()]

    def set_tags(self, tags: Optional[List[str]]) -> None:
        if tags:
            self.tags = ",".join(sorted(set([tag.strip() for tag in tags if tag.strip()])))
        else:
            self.tags = None


class Board(BaseModel):
    __tablename__ = "boards"

    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    nome = db.Column(db.String(255), nullable=False)

    user = db.relationship("User", back_populates="boards")
    items = db.relationship("BoardItem", back_populates="board", cascade="all, delete-orphan")


class BoardItem(BaseModel):
    __tablename__ = "board_items"

    board_id = db.Column(db.Integer, db.ForeignKey("boards.id"), nullable=False, index=True)
    texto = db.Column(db.String(500), nullable=False)
    img_url = db.Column(db.String(255))
    audio_url = db.Column(db.String(255))
    emoji = db.Column(db.String(16))
    categoria = db.Column(db.String(100))

    board = db.relationship("Board", back_populates="items")


class Share(BaseModel):
    __tablename__ = "shares"

    owner_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    viewer_id = db.Column(db.Integer, db.ForeignKey("users.id"), index=True)
    viewer_email = db.Column(db.String(255), nullable=False)
    escopo = db.Column(db.String(50), nullable=False, default="read")
    expira_em = db.Column(db.DateTime)

    owner = db.relationship("User", foreign_keys=[owner_id], back_populates="shares_owned")
    viewer = db.relationship("User", foreign_keys=[viewer_id], back_populates="shares_received")


class CareLink(BaseModel):
    __tablename__ = "care_links"

    cuidador_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    pessoa_tea_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    status = db.Column(db.String(50), nullable=False, default="pending")  # pending, accepted, rejected
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    cuidador = db.relationship("User", foreign_keys=[cuidador_id], back_populates="care_links_as_cuidador")
    pessoa_tea = db.relationship("User", foreign_keys=[pessoa_tea_id], back_populates="care_links_as_pessoa_tea")

    __table_args__ = (
        db.UniqueConstraint('cuidador_id', 'pessoa_tea_id', name='unique_care_link'),
    )


class Notification(BaseModel):
    __tablename__ = "notifications"

    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    tipo = db.Column(db.String(50), nullable=False)  # care_link_request, care_link_accepted, share_request, share_accepted, etc.
    titulo = db.Column(db.String(255), nullable=False)
    mensagem = db.Column(db.Text, nullable=False)
    lida = db.Column(db.Boolean, default=False, nullable=False)
    care_link_id = db.Column(db.Integer, db.ForeignKey("care_links.id"), nullable=True, index=True)
    share_id = db.Column(db.Integer, db.ForeignKey("shares.id"), nullable=True, index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    user = db.relationship("User", back_populates="notifications")
    care_link = db.relationship("CareLink", foreign_keys=[care_link_id])
    share = db.relationship("Share", foreign_keys=[share_id])


