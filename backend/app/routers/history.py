"""Historial de búsquedas por usuario (append-only, deduplicado por op_id)."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, select

from ..database import get_session
from ..models import SearchHistory, User
from ..schemas import HistoryCreate, HistoryRead
from ..security import get_current_user

router = APIRouter(prefix="/history", tags=["history"])


def _read(item: SearchHistory) -> HistoryRead:
    return HistoryRead.model_validate(item, from_attributes=True)


@router.get("", response_model=list[HistoryRead])
def listar(
    limit: int = Query(default=100, ge=1, le=500),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    query = (
        select(SearchHistory)
        .where(SearchHistory.user_id == user.id)
        .order_by(SearchHistory.created_at.desc())
        .limit(limit)
    )
    return [_read(item) for item in session.exec(query).all()]


@router.post("", response_model=HistoryRead, status_code=201)
def agregar(
    payload: HistoryCreate,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    if payload.op_id:
        duplicate = session.exec(
            select(SearchHistory).where(SearchHistory.op_id == payload.op_id)
        ).first()
        if duplicate is not None:
            return _read(duplicate)

    item = SearchHistory(
        id=payload.id or str(uuid.uuid4()),
        user_id=user.id,
        query=payload.query.strip(),
        op_id=payload.op_id,
        created_at=payload.created_at or datetime.now(timezone.utc),
    )
    session.add(item)
    session.commit()
    session.refresh(item)
    return _read(item)


@router.delete("", status_code=200)
def limpiar(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    items = session.exec(
        select(SearchHistory).where(SearchHistory.user_id == user.id)
    ).all()
    for item in items:
        session.delete(item)
    session.commit()
    return {"detail": "Historial eliminado", "deleted": len(items)}


def apply_history_add(session: Session, user: User, data: dict) -> dict:
    op_id = data.get("op_id")
    if op_id:
        duplicate = session.exec(
            select(SearchHistory).where(SearchHistory.op_id == op_id)
        ).first()
        if duplicate is not None:
            return {"id": duplicate.id, "duplicate": True}

    query = str(data.get("query") or "").strip()
    if not query:
        raise ValueError("Falta query")
    item_id = str(data.get("id") or uuid.uuid4())
    item = SearchHistory(
        id=item_id,
        user_id=user.id,
        query=query,
        op_id=op_id,
        created_at=datetime.now(timezone.utc),
    )
    session.add(item)
    session.flush()
    return {"id": item_id, "duplicate": False}
