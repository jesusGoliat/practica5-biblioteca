"""CRUD de libros guardados (extensión CRUD de la Práctica 2)."""

import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from ..database import get_session
from ..models import LibraryItem, User
from ..schemas import LibraryItemCreate, LibraryItemRead, LibraryItemUpdate
from ..security import get_current_user

router = APIRouter(prefix="/library", tags=["library"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _read(item: LibraryItem) -> LibraryItemRead:
    return LibraryItemRead.model_validate(item, from_attributes=True)


def _get_owned(public_id: str, session: Session, user: User) -> LibraryItem:
    item = session.get(LibraryItem, public_id)
    if item is None or item.user_id != user.id or item.deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Libro no encontrado"
        )
    return item


@router.get("", response_model=list[LibraryItemRead])
def listar(
    include_deleted: bool = Query(default=False),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    query = select(LibraryItem).where(LibraryItem.user_id == user.id)
    if not include_deleted:
        query = query.where(LibraryItem.deleted == False)  # noqa: E712
    return [_read(item) for item in session.exec(query).all()]


@router.post("", response_model=LibraryItemRead, status_code=status.HTTP_201_CREATED)
def crear(
    payload: LibraryItemCreate,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    public_id = (payload.public_id or str(uuid.uuid4())).strip()
    existing = session.get(LibraryItem, public_id)
    if existing is not None:
        if existing.user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El identificador del libro ya pertenece a otro usuario",
            )
        return _read(existing)

    # Evita duplicados del mismo libro para el mismo usuario.
    same_book = session.exec(
        select(LibraryItem).where(
            LibraryItem.user_id == user.id,
            LibraryItem.ol_key == payload.ol_key,
        )
    ).first()
    if same_book is not None:
        same_book.deleted = False
        same_book.updated_at = _now()
        session.add(same_book)
        session.commit()
        session.refresh(same_book)
        return _read(same_book)

    item = LibraryItem(
        public_id=public_id,
        user_id=user.id,
        ol_key=payload.ol_key,
        title=payload.title,
        author=payload.author,
        cover_id=payload.cover_id,
        status=payload.status,
        rating=payload.rating,
        notes=payload.notes,
    )
    session.add(item)
    session.commit()
    session.refresh(item)
    return _read(item)


@router.get("/{public_id}", response_model=LibraryItemRead)
def obtener(
    public_id: str,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    return _read(_get_owned(public_id, session, user))


@router.put("/{public_id}", response_model=LibraryItemRead)
def actualizar(
    public_id: str,
    payload: LibraryItemUpdate,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    item = _get_owned(public_id, session, user)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se recibio ningun campo para actualizar",
        )
    for field, value in updates.items():
        setattr(item, field, value)
    item.updated_at = _now()
    session.add(item)
    session.commit()
    session.refresh(item)
    return _read(item)


@router.delete("/{public_id}", status_code=status.HTTP_200_OK)
def borrar(
    public_id: str,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    item = _get_owned(public_id, session, user)
    item.deleted = True
    item.updated_at = _now()
    session.add(item)
    session.commit()
    return {"detail": "Libro eliminado", "public_id": public_id}


# --------------------------------------------------------------------------- #
# Helpers para /sync (usan la misma lógica y respetan el dueño)
# --------------------------------------------------------------------------- #
def apply_library_upsert(session: Session, user: User, data: dict) -> dict:
    public_id = str(data.get("public_id") or uuid.uuid4())
    existing = session.get(LibraryItem, public_id)
    if existing is not None and existing.user_id != user.id:
        raise ValueError("public_id pertenece a otro usuario")

    if existing is None:
        existing = session.exec(
            select(LibraryItem).where(
                LibraryItem.user_id == user.id,
                LibraryItem.ol_key == str(data["ol_key"]),
            )
        ).first()

    if existing is None:
        existing = LibraryItem(
            public_id=public_id,
            user_id=user.id,
            ol_key=str(data["ol_key"]),
            title=str(data.get("title") or "Sin titulo"),
            author=data.get("author"),
            cover_id=data.get("cover_id"),
            status=data.get("status", "want_to_read"),
            rating=data.get("rating"),
            notes=data.get("notes"),
        )
    else:
        existing.deleted = bool(data.get("deleted", False))
        existing.title = str(data.get("title") or existing.title)
        existing.author = data.get("author", existing.author)
        existing.cover_id = data.get("cover_id", existing.cover_id)
        existing.status = data.get("status", existing.status)
        existing.rating = data.get("rating", existing.rating)
        existing.notes = data.get("notes", existing.notes)
        existing.updated_at = _now()

    session.add(existing)
    session.flush()
    return {"public_id": existing.public_id, "deleted": existing.deleted}


def apply_library_delete(session: Session, user: User, data: dict) -> dict:
    public_id = str(data.get("public_id") or "")
    item = session.get(LibraryItem, public_id) if public_id else None
    if item is None:
        # Tombstone idempotente: si no existe, no hay nada que borrar.
        return {"public_id": public_id, "deleted": True}
    if item.user_id != user.id:
        raise ValueError("El libro pertenece a otro usuario")
    item.deleted = True
    item.updated_at = _now()
    session.add(item)
    session.flush()
    return {"public_id": item.public_id, "deleted": True}
