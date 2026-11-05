"""Modelos SQLModel de la Práctica 5.

Conserva User/Tarea de la Práctica 2 y agrega las tablas de la Práctica 5:
LibraryItem, Favorite, SearchHistory y SyncOperation.

Todos los valores por defecto se calculan en Python (no con `now()` ni JSONB)
para que el backend pueda correr también con SQLite en los tests y en el job
de iOS de GitHub Actions.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel
from sqlalchemy import UniqueConstraint


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    # `username` se conserva de la Práctica 2. En la P5 se usa el correo como
    # username para los usuarios nuevos, pero se acepta cualquier alias.
    username: str = Field(index=True, unique=True, nullable=False)
    email: Optional[str] = Field(default=None, index=True, unique=True)
    name: Optional[str] = Field(default=None, max_length=120)
    hashed_password: Optional[str] = None
    google_sub: Optional[str] = Field(default=None, index=True, unique=True)
    role: str = Field(default="user", index=True)  # user | admin
    created_at: datetime = Field(default_factory=_utcnow)


class Tarea(SQLModel, table=True):
    """Recurso de la Práctica 2; se conserva como regresión."""

    id: Optional[int] = Field(default=None, primary_key=True)
    titulo: str
    descripcion: Optional[str] = None
    completada: bool = Field(default=False)
    owner_id: int = Field(foreign_key="user.id", index=True)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class LibraryItem(SQLModel, table=True):
    """Libro guardado por el usuario (CRUD de la P5).

    `public_id` lo genera el cliente (UUID) para que una creación offline sea
    idempotente y para poder hacer pull antes de push sin duplicar.
    """

    __table_args__ = (
        UniqueConstraint("user_id", "ol_key", name="uq_library_user_key"),
    )

    public_id: str = Field(primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    ol_key: str = Field(index=True)
    title: str
    author: Optional[str] = None
    cover_id: Optional[int] = None
    status: str = Field(default="want_to_read")  # want_to_read | reading | read
    rating: Optional[int] = None
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)
    deleted: bool = Field(default=False, index=True)


class Favorite(SQLModel, table=True):
    __table_args__ = (
        UniqueConstraint("user_id", "ol_key", name="uq_favorite_user_key"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    ol_key: str = Field(index=True)
    title: str
    author: Optional[str] = None
    cover_id: Optional[int] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)
    deleted: bool = Field(default=False, index=True)


class SearchHistory(SQLModel, table=True):
    id: str = Field(primary_key=True)  # UUID del cliente
    user_id: int = Field(foreign_key="user.id", index=True)
    query: str = Field(max_length=300)
    created_at: datetime = Field(default_factory=_utcnow)
    op_id: Optional[str] = Field(default=None, index=True, unique=True)


class SyncOperation(SQLModel, table=True):
    """Registro de idempotencia: cada `op_id` se aplica una sola vez."""

    op_id: str = Field(primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    type: str
    status: str = "applied"  # applied | error
    result_json: str = "{}"
    applied_at: datetime = Field(default_factory=_utcnow)
