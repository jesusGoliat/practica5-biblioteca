"""Registro, login (correo/contraseña y Google) y sesión."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from ..database import get_session
from ..models import User
from ..schemas import GoogleLogin, Token, UserCreate, UserLogin, UserRead
from ..security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_google_id_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _user_read(user: User) -> UserRead:
    return UserRead.model_validate(user, from_attributes=True)


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, session: Session = Depends(get_session)):
    username = payload.username.strip().lower()
    email = (payload.email or (username if "@" in username else None) or "").strip().lower() or None

    existing = session.exec(select(User).where(User.username == username)).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="El usuario ya existe"
        )
    if email:
        duplicate = session.exec(select(User).where(User.email == email)).first()
        if duplicate:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="El correo ya esta registrado"
            )

    user = User(
        username=username,
        email=email,
        name=payload.name,
        hashed_password=hash_password(payload.password),
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return _user_read(user)


@router.post("/login", response_model=Token)
def login(payload: UserLogin, session: Session = Depends(get_session)):
    identifier = payload.username.strip().lower()
    user = session.exec(select(User).where(User.username == identifier)).first()
    if user is None:
        user = session.exec(select(User).where(User.email == identifier)).first()
    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contrasena incorrectos",
        )
    if not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contrasena incorrectos",
        )

    token, expires_in = create_access_token(user)
    return Token(access_token=token, expires_in=expires_in, user=_user_read(user))


@router.post("/google", response_model=Token)
def google_login(payload: GoogleLogin, session: Session = Depends(get_session)):
    info = verify_google_id_token(payload.id_token)

    google_sub = str(info["sub"])
    email = (info.get("email") or "").strip().lower() or None
    name = info.get("name") or None

    user = session.exec(select(User).where(User.google_sub == google_sub)).first()
    if user is None and email:
        user = session.exec(select(User).where(User.email == email)).first()
    if user is None:
        username = email or f"google_{google_sub[:16]}"
        user = User(
            username=username,
            email=email,
            name=name,
            google_sub=google_sub,
        )
        session.add(user)
        session.commit()
        session.refresh(user)
    else:
        # Vincula la cuenta existente con Google sin duplicarla.
        if user.google_sub is None:
            user.google_sub = google_sub
        if email and not user.email:
            user.email = email
        if name and not user.name:
            user.name = name
        session.add(user)
        session.commit()
        session.refresh(user)

    token, expires_in = create_access_token(user)
    return Token(access_token=token, expires_in=expires_in, user=_user_read(user))


@router.get("/me", response_model=UserRead)
def me(user: User = Depends(get_current_user)):
    return _user_read(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(user: User = Depends(get_current_user)):
    # JWT stateless: el cliente elimina el token del almacenamiento seguro.
    # Se expone el endpoint para que la app tenga un cierre de sesión explícito.
    return None
