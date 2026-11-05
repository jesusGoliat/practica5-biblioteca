from conftest import login, register


def test_registro_login_y_me(api):
    response = register(api)
    assert response.status_code == 201, response.text
    assert response.json()["role"] == "user"

    token = login(api)
    me = api.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["username"] == "ana@biblioteca.test"


def test_login_incorrecto(api):
    register(api)
    response = api.post(
        "/auth/login",
        json={"username": "ana@biblioteca.test", "password": "incorrecta"},
    )
    assert response.status_code == 401


def test_registro_duplicado(api):
    assert register(api).status_code == 201
    assert register(api).status_code == 400


def test_google_login_valida_token(api, monkeypatch):
    def fake_verify(raw_token):
        assert raw_token == "token-de-prueba-google"
        return {
            "sub": "google-sub-123",
            "email": "gmail@biblioteca.test",
            "email_verified": True,
            "name": "Usuario Google",
            "iss": "https://accounts.google.com",
        }

    monkeypatch.setattr("app.routers.auth.verify_google_id_token", fake_verify)
    response = api.post("/auth/google", json={"id_token": "token-de-prueba-google"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["user"]["email"] == "gmail@biblioteca.test"
    assert body["access_token"]

    # El mismo `sub` no debe duplicar la cuenta en un segundo login.
    again = api.post("/auth/google", json={"id_token": "token-de-prueba-google"})
    assert again.status_code == 200
    assert again.json()["user"]["id"] == body["user"]["id"]
