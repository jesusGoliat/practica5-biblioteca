"""Esquemas Pydantic de request/response de la Práctica 5."""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


# --------------------------------------------------------------------------- #
# Autenticación y usuarios
# --------------------------------------------------------------------------- #
class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=80)
    password: str = Field(min_length=8, max_length=128)
    email: Optional[str] = Field(default=None, max_length=160)
    name: Optional[str] = Field(default=None, max_length=120)

    @field_validator("username")
    @classmethod
    def normaliza_username(cls, value: str) -> str:
        return value.strip().lower()


class UserLogin(BaseModel):
    username: str
    password: str


class GoogleLogin(BaseModel):
    id_token: str = Field(min_length=20)


class UserRead(BaseModel):
    id: int
    username: str
    email: Optional[str] = None
    name: Optional[str] = None
    role: str = "user"
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserRead


# --------------------------------------------------------------------------- #
# Práctica 2 (regresión)
# --------------------------------------------------------------------------- #
class TareaCreate(BaseModel):
    titulo: str = Field(min_length=1, max_length=200)
    descripcion: Optional[str] = Field(default=None, max_length=1000)
    completada: bool = False


class TareaUpdate(BaseModel):
    titulo: Optional[str] = Field(default=None, min_length=1, max_length=200)
    descripcion: Optional[str] = Field(default=None, max_length=1000)
    completada: Optional[bool] = None


class TareaRead(BaseModel):
    id: int
    titulo: str
    descripcion: Optional[str]
    completada: bool
    owner_id: int
    created_at: datetime
    updated_at: datetime


# --------------------------------------------------------------------------- #
# Biblioteca (CRUD de libros guardados)
# --------------------------------------------------------------------------- #
class LibraryItemCreate(BaseModel):
    public_id: Optional[str] = Field(default=None, max_length=64)
    ol_key: str = Field(min_length=1, max_length=200)
    title: str = Field(min_length=1, max_length=300)
    author: Optional[str] = Field(default=None, max_length=300)
    cover_id: Optional[int] = None
    status: Literal["want_to_read", "reading", "read"] = "want_to_read"
    rating: Optional[int] = Field(default=None, ge=0, le=5)
    notes: Optional[str] = Field(default=None, max_length=2000)


class LibraryItemUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=300)
    author: Optional[str] = Field(default=None, max_length=300)
    cover_id: Optional[int] = None
    status: Optional[Literal["want_to_read", "reading", "read"]] = None
    rating: Optional[int] = Field(default=None, ge=0, le=5)
    notes: Optional[str] = Field(default=None, max_length=2000)


class LibraryItemRead(BaseModel):
    public_id: str
    ol_key: str
    title: str
    author: Optional[str]
    cover_id: Optional[int]
    status: str
    rating: Optional[int]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    deleted: bool = False


# --------------------------------------------------------------------------- #
# Favoritos
# --------------------------------------------------------------------------- #
class FavoriteSet(BaseModel):
    ol_key: str = Field(min_length=1, max_length=200)
    title: str = Field(min_length=1, max_length=300)
    author: Optional[str] = Field(default=None, max_length=300)
    cover_id: Optional[int] = None
    favorite: bool = True


class FavoriteRead(BaseModel):
    ol_key: str
    title: str
    author: Optional[str]
    cover_id: Optional[int]
    created_at: datetime
    updated_at: datetime
    deleted: bool = False


# --------------------------------------------------------------------------- #
# Historial de búsquedas
# --------------------------------------------------------------------------- #
class HistoryCreate(BaseModel):
    query: str = Field(min_length=1, max_length=300)
    id: Optional[str] = Field(default=None, max_length=64)
    op_id: Optional[str] = Field(default=None, max_length=64)
    created_at: Optional[datetime] = None


class HistoryRead(BaseModel):
    id: str
    query: str
    created_at: datetime


# --------------------------------------------------------------------------- #
# Sincronización idempotente
# --------------------------------------------------------------------------- #
class SyncOperationIn(BaseModel):
    op_id: str = Field(min_length=8, max_length=80)
    type: Literal["favorite_set", "library_upsert", "library_delete", "history_add"]
    data: dict


class SyncBatch(BaseModel):
    operations: list[SyncOperationIn] = Field(default_factory=list, max_length=200)


class SyncOperationResult(BaseModel):
    op_id: str
    status: Literal["applied", "duplicate", "error"]
    detail: Optional[str] = None
    result: Optional[dict] = None


class SyncBatchResult(BaseModel):
    results: list[SyncOperationResult]
    server_time: datetime


# --------------------------------------------------------------------------- #
# Administración
# --------------------------------------------------------------------------- #
class AdminUserRead(BaseModel):
    id: int
    username: str
    email: Optional[str]
    name: Optional[str]
    role: str
    created_at: datetime
    favorites: int = 0
    history: int = 0
    library: int = 0
