from conftest import _auth_headers


def _fav(**overrides):
    data = {
        "ol_key": "/works/OL893414W",
        "title": "Dune",
        "author": "Frank Herbert",
        "cover_id": 11481354,
        "favorite": True,
    }
    data.update(overrides)
    return data


def test_favoritos_marcar_desmarcar(api, user_token):
    headers = _auth_headers(user_token)
    created = api.put("/favorites", json=_fav(), headers=headers)
    assert created.status_code == 200, created.text
    assert created.json()["deleted"] is False
    assert len(api.get("/favorites", headers=headers).json()) == 1

    removed = api.put("/favorites", json=_fav(favorite=False), headers=headers)
    assert removed.status_code == 200
    assert removed.json()["deleted"] is True
    assert api.get("/favorites", headers=headers).json() == []

    # Volver a marcar no duplica.
    api.put("/favorites", json=_fav(), headers=headers)
    assert len(api.get("/favorites", headers=headers).json()) == 1


def test_historial(api, user_token):
    headers = _auth_headers(user_token)
    first = api.post("/history", json={"query": "dune"}, headers=headers)
    assert first.status_code == 201, first.text
    assert api.post("/history", json={"query": "asimov"}, headers=headers).status_code == 201

    listed = api.get("/history", headers=headers)
    assert listed.status_code == 200
    assert {item["query"] for item in listed.json()} == {"dune", "asimov"}

    assert api.delete("/history", headers=headers).status_code == 200
    assert api.get("/history", headers=headers).json() == []
