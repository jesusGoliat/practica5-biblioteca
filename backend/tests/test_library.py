from conftest import _auth_headers, create_user, login


def _book(**overrides):
    data = {
        "public_id": "11111111-1111-1111-1111-111111111111",
        "ol_key": "/works/OL893414W",
        "title": "Dune",
        "author": "Frank Herbert",
        "cover_id": 11481354,
        "status": "want_to_read",
    }
    data.update(overrides)
    return data


def test_crud_completo(api, user_token):
    headers = _auth_headers(user_token)

    created = api.post("/library", json=_book(), headers=headers)
    assert created.status_code == 201, created.text
    public_id = created.json()["public_id"]

    listed = api.get("/library", headers=headers)
    assert listed.status_code == 200
    assert len(listed.json()) == 1

    updated = api.put(
        f"/library/{public_id}",
        json={"status": "reading", "rating": 5, "notes": "Excelente"},
        headers=headers,
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["status"] == "reading"
    assert updated.json()["rating"] == 5

    deleted = api.delete(f"/library/{public_id}", headers=headers)
    assert deleted.status_code == 200
    assert api.get("/library", headers=headers).json() == []
    assert len(api.get("/library?include_deleted=true", headers=headers).json()) == 1


def test_aislamiento_entre_usuarios(api, user_token):
    create_user(username="luis@biblioteca.test")
    luis_token = login(api, username="luis@biblioteca.test")
    headers_ana = _auth_headers(user_token)
    headers_luis = _auth_headers(luis_token)

    created = api.post("/library", json=_book(), headers=headers_ana)
    public_id = created.json()["public_id"]

    assert api.get(f"/library/{public_id}", headers=headers_luis).status_code == 404
    assert api.put(
        f"/library/{public_id}", json={"rating": 1}, headers=headers_luis
    ).status_code == 404
    assert api.delete(f"/library/{public_id}", headers=headers_luis).status_code == 404
    assert api.get("/library", headers=headers_luis).json() == []


def test_post_idempotente_mismo_libro(api, user_token):
    headers = _auth_headers(user_token)
    first = api.post("/library", json=_book(), headers=headers)
    second = api.post("/library", json=_book(public_id="otro-id"), headers=headers)
    assert first.status_code == 201
    assert second.status_code == 201
    assert len(api.get("/library", headers=headers).json()) == 1
