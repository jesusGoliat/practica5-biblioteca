"""Crea o promueve la cuenta administrador de la práctica.

Uso (dentro del contenedor o con el venv local):
    python -m app.bootstrap_admin

Requiere ADMIN_EMAIL y ADMIN_PASSWORD en el entorno (backend/.env).
"""

import os

from sqlmodel import Session, select

from .database import engine, init_db
from .models import User
from .security import hash_password


def main() -> None:
    email = (os.getenv("ADMIN_EMAIL") or "").strip().lower()
    password = os.getenv("ADMIN_PASSWORD") or ""
    name = (os.getenv("ADMIN_NAME") or "Administrador").strip()

    if not email or not password:
        raise SystemExit(
            "Define ADMIN_EMAIL y ADMIN_PASSWORD (por ejemplo en backend/.env)."
        )

    init_db()
    with Session(engine) as session:
        user = session.exec(select(User).where(User.email == email)).first()
        if user is None:
            user = session.exec(select(User).where(User.username == email)).first()

        if user is None:
            user = User(
                username=email,
                email=email,
                name=name,
                hashed_password=hash_password(password),
                role="admin",
            )
            action = "creada"
        else:
            user.role = "admin"
            user.hashed_password = hash_password(password)
            user.email = user.email or email
            user.name = user.name or name
            action = "actualizada"

        session.add(user)
        session.commit()
        print(f"Cuenta administrador {action}: {email}")


if __name__ == "__main__":
    main()
