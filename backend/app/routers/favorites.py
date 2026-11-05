"""Favoritos por usuario, persistentes y sincronizables."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, select

from ..database import get_session
from ..models import Favorite, User
from ..schemas import FavoriteRead, FavoriteSet
from ..security import get_current_user

router = APIRouter(prefix="/favorites", tags=["favorites"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _read(fav: Favorite) -> FavoriteRead:
    return FavoriteRead.model_validate(fav, from_attributes=True)


def _find(session: Session, user: User, ol_key: str) -> Favorite | None:
    return session.exec(
        select(Favorite).where(
            Favorite.user_id == user.id,
            Favorite.ol_key == ol_key,
        )
    ).first()


@router.get("", response_model=list[FavoriteRead])
def listar(
    include_deleted: bool = Query(default=False),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    query = select(Favorite).where(Favorite.user_id == user.id)
    if not include_deleted:
        query = query.where(Favorite.deleted == False)  # noqa: E712
    return [_read(fav) for fav in session.exec(query).all()]


@router.put("", response_model=FavoriteRead)
def establecer(
    payload: FavoriteSet,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    fav = _find(session, user, payload.ol_key)
    if fav is None:
        fav = Favorite(
            user_id=user.id,
            ol_key=payload.ol_key,
            title=payload.title,
            author=payload.author,
            cover_id=payload.cover_id,
            deleted=not payload.favorite,
        )
    else:
        fav.title = payload.title
        fav.author = payload.author
        fav.cover_id = payload.cover_id
        fav.deleted = not payload.favorite
        fav.updated_at = _now()
    session.add(fav)
    session.commit()
    session.refresh(fav)
    return _read(fav)


@router.delete("", response_model=FavoriteRead)
def quitar(
    payload: FavoriteSet,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    payload.favorite = False
    return establecer(payload, session=session, user=user)


def apply_favorite_set(session: Session, user: User, data: dict) -> dict:
    ol_key = str(data.get("ol_key") or "")
    if not ol_key:
        raise ValueError("Falta ol_key")
    favorite = bool(data.get("favorite", True))
    fav = _find(session, user, ol_key)
    if fav is None:
        fav = Favorite(
            user_id=user.id,
            ol_key=ol_key,
            title=str(data.get("title") or "Sin titulo"),
            author=data.get("author"),
            cover_id=data.get("cover_id"),
            deleted=not favorite,
        )
    else:
        fav.title = str(data.get("title") or fav.title)
        fav.author = data.get("author", fav.author)
        fav.cover_id = data.get("cover_id", fav.cover_id)
        fav.deleted = not favorite
        fav.updated_at = _now()
    session.add(fav)
    session.flush()
    return {"ol_key": ol_key, "favorite": favorite}
