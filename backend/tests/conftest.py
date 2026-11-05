import os

# Debe definirse antes de importar la app: database.py y security.py leen env.
os.environ.setdefault("JWT_SECRET", "test-secret-practica5")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_practica5.db")
os.environ.setdefault("GOOGLE_CLIENT_IDS", "web-test.apps.googleusercontent.com")

import pytest
from fastapi.testclient import TestClient
from sqlmodel import SQLModel, Session

from app.database import engine
from app.main import app
from app.models import User
from app.security import hash_password

client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_db():
    SQLModel.metadata.drop_all(engine)
    SQLModel.metadata.create_all(engine)
    yield


@pytest.fixture
def api():
    return client


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def register(api, username="ana@biblioteca.test", password="secreto123", name="Ana"):
    return api.post(
        "/auth/register",
        json={"username": username, "password": password, "name": name},
    )


def login(api, username="ana@biblioteca.test", password="secreto123"):
    response = api.post("/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def create_user(username="ana@biblioteca.test", password="secreto123", role="user"):
    with Session(engine) as session:
        user = User(
            username=username,
            email=username,
            name=username,
            hashed_password=hash_password(password),
            role=role,
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return user.id


@pytest.fixture
def user_token(api):
    create_user()
    return login(api)


@pytest.fixture
def admin_token(api):
    create_user(username="admin@biblioteca.test", role="admin")
    return login(api, username="admin@biblioteca.test")
