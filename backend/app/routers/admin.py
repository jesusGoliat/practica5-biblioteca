"""Endpoints exclusivos del rol administrador.

La autorización se valida contra el rol guardado en la base de datos
(`get_current_admin`), no sólo contra el claim del JWT ni ocultando la UI.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlmodel import Session, select

from ..database import get_session
from ..models import Favorite, LibraryItem, SearchHistory, User
from ..schemas import (
    AdminUserRead,
    FavoriteRead,
    HistoryRead,
    LibraryItemRead,
)
from ..security import get_current_admin

router = APIRouter(prefix="/admin", tags=["admin"])


def _count(session: Session, model, user_id: int) -> int:
    query = select(func.count()).select_from(model).where(model.user_id == user_id)
    if hasattr(model, "deleted"):
        query = query.where(model.deleted == False)  # noqa: E712 - borrado lógico
    return int(session.exec(query).one())


@router.get("/users", response_model=list[AdminUserRead])
def listar_usuarios(
    session: Session = Depends(get_session),
    _: User = Depends(get_current_admin),
):
    users = session.exec(select(User).order_by(User.id)).all()
    return [
        AdminUserRead(
            id=user.id,
            username=user.username,
            email=user.email,
            name=user.name,
            role=user.role,
            created_at=user.created_at,
            favorites=_count(session, Favorite, user.id),
            history=_count(session, SearchHistory, user.id),
            library=_count(session, LibraryItem, user.id),
        )
        for user in users
    ]


def _target(session: Session, user_id: int) -> User:
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado"
        )
    return user


@router.get("/users/{user_id}/history", response_model=list[HistoryRead])
def historial_de_usuario(
    user_id: int,
    session: Session = Depends(get_session),
    _: User = Depends(get_current_admin),
):
    _target(session, user_id)
    items = session.exec(
        select(SearchHistory)
        .where(SearchHistory.user_id == user_id)
        .order_by(SearchHistory.created_at.desc())
    ).all()
    return [HistoryRead.model_validate(item, from_attributes=True) for item in items]


@router.get("/users/{user_id}/favorites", response_model=list[FavoriteRead])
def favoritos_de_usuario(
    user_id: int,
    session: Session = Depends(get_session),
    _: User = Depends(get_current_admin),
):
    _target(session, user_id)
    items = session.exec(
        select(Favorite).where(
            Favorite.user_id == user_id,
            Favorite.deleted == False,  # noqa: E712
        )
    ).all()
    return [FavoriteRead.model_validate(item, from_attributes=True) for item in items]


@router.get("/users/{user_id}/library", response_model=list[LibraryItemRead])
def biblioteca_de_usuario(
    user_id: int,
    session: Session = Depends(get_session),
    _: User = Depends(get_current_admin),
):
    _target(session, user_id)
    items = session.exec(
        select(LibraryItem).where(
            LibraryItem.user_id == user_id,
            LibraryItem.deleted == False,  # noqa: E712
        )
    ).all()
    return [LibraryItemRead.model_validate(item, from_attributes=True) for item in items]


@router.get("/overview")
def resumen(
    session: Session = Depends(get_session),
    _: User = Depends(get_current_admin),
):
    return {
        "users": int(session.exec(select(func.count()).select_from(User)).one()),
        "favorites": int(
            session.exec(select(func.count()).select_from(Favorite)).one()
        ),
        "history": int(
            session.exec(select(func.count()).select_from(SearchHistory)).one()
        ),
        "library": int(
            session.exec(select(func.count()).select_from(LibraryItem)).one()
        ),
    }
