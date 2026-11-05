"""Hash de contraseñas, JWT, autorización y validación de Google ID tokens."""

import os
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlmodel import Session, select

from .database import get_session
from .models import User

JWT_SECRET = os.getenv("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError(
        "JWT_SECRET no esta configurado. Define la variable de entorno JWT_SECRET "
        "(ver backend/.env.example)."
    )

JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "1440"))
GOOGLE_CLIENT_IDS = [
    value.strip()
    for value in os.getenv("GOOGLE_CLIENT_IDS", "").split(",")
    if value.strip()
]

_hasher = PasswordHasher()
_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login", auto_error=False)


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return _hasher.verify(hashed, password)
    except VerifyMismatchError:
        return False


def create_access_token(user: User) -> tuple[str, int]:
    expires_delta = timedelta(minutes=JWT_EXPIRE_MINUTES)
    expire = datetime.now(timezone.utc) + expires_delta
    payload = {
        "sub": str(user.id),
        "username": user.username,
        "role": user.role,
        "exp": expire,
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return token, int(expires_delta.total_seconds())


def _unauthorized(detail: str = "No hay una sesion valida (token ausente, invalido o expirado)"):
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    token: str | None = Depends(_oauth2_scheme),
    session: Session = Depends(get_session),
) -> User:
    if token is None:
        raise _unauthorized()

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise _unauthorized()

    subject = payload.get("sub")
    if subject is None:
        raise _unauthorized()

    # Los tokens nuevos usan el id numerico; los viejos de la Practica 2 usan
    # el username. Se aceptan ambos para no romper /tareas.
    user = None
    if str(subject).isdigit():
        user = session.get(User, int(subject))
    if user is None:
        user = session.exec(select(User).where(User.username == str(subject))).first()
    if user is None:
        raise _unauthorized()
    return user


def get_current_admin(user: User = Depends(get_current_user)) -> User:
    """Autoriza leyendo el rol de la base de datos, no solo el claim JWT.

    Esto cumple el requisito de que los permisos se validen en el backend y no
    solo ocultando elementos en la interfaz.
    """

    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere el rol de administrador",
        )
    return user


def verify_google_id_token(raw_token: str) -> dict[str, Any]:
    """Valida un ID token de Google contra la lista de client IDs permitidos."""

    if not GOOGLE_CLIENT_IDS:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Google Sign-In no esta configurado en el servidor. "
                "Define GOOGLE_CLIENT_IDS en backend/.env."
            ),
        )

    try:
        info = google_id_token.verify_oauth2_token(
            raw_token,
            google_requests.Request(),
            audience=GOOGLE_CLIENT_IDS,
            clock_skew_in_seconds=10,
        )
    except Exception as exc:  # noqa: BLE001 - se traduce a 401
        raise _unauthorized(f"ID token de Google invalido: {exc}") from exc

    if info.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise _unauthorized("Emisor de Google invalido")
    if not info.get("email_verified"):
        raise _unauthorized("El correo de Google no esta verificado")
    if not info.get("sub"):
        raise _unauthorized("El ID token no contiene el identificador de usuario")
    return info
