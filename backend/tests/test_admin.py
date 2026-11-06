from conftest import _auth_headers, create_user, login


def test_admin_puede_consultar_usuarios(api, admin_token, user_token):
    create_user(username="ana2@biblioteca.test")
    ana_token = login(api, username="ana2@biblioteca.test")
    created = api.put(
        "/favorites",
        json={"ol_key": "/works/OL1W", "title": "Libro", "favorite": True},
        headers=_auth_headers(ana_token),
    )
    assert created.status_code == 200, created.text

    users = api.get("/admin/users", headers=_auth_headers(admin_token))
    assert users.status_code == 200, users.text
    target = next(
        user for user in users.json() if user["username"] == "ana2@biblioteca.test"
    )

    favorites = api.get(
        f"/admin/users/{target['id']}/favorites", headers=_auth_headers(admin_token)
    )
    assert favorites.status_code == 200
    assert len(favorites.json()) == 1


def test_usuario_normal_recibe_403(api, user_token):
    headers = _auth_headers(user_token)
    assert api.get("/admin/users", headers=headers).status_code == 403
    assert api.get("/admin/users/1/history", headers=headers).status_code == 403
    assert api.get("/admin/overview", headers=headers).status_code == 403


def test_sin_token_recibe_401(api):
    assert api.get("/admin/users").status_code == 401


def test_contadores_del_admin_excluyen_borrados_logicos(api, admin_token):
    create_user(username="bea@biblioteca.test")
    token = login(api, username="bea@biblioteca.test")
    headers = _auth_headers(token)
    for favorite in (True, False):
        response = api.put(
            "/favorites",
            json={"ol_key": "/works/OL7W", "title": "Libro", "favorite": favorite},
            headers=headers,
        )
        assert response.status_code == 200, response.text

    users = api.get("/admin/users", headers=_auth_headers(admin_token)).json()
    target = next(u for u in users if u["username"] == "bea@biblioteca.test")
    assert target["favorites"] == 0
