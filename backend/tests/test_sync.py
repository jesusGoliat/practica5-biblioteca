from conftest import _auth_headers


def test_sync_favorito_idempotente(api, user_token):
    headers = _auth_headers(user_token)
    op = {
        "op_id": "op-favorito-0001",
        "type": "favorite_set",
        "data": {
            "ol_key": "/works/OL893414W",
            "title": "Dune",
            "author": "Frank Herbert",
            "cover_id": 11481354,
            "favorite": True,
        },
    }

    first = api.post("/sync", json={"operations": [op]}, headers=headers)
    assert first.status_code == 200, first.text
    assert first.json()["results"][0]["status"] == "applied"

    # Reintento exacto: no debe duplicar el favorito.
    retry = api.post("/sync", json={"operations": [op]}, headers=headers)
    assert retry.status_code == 200
    assert retry.json()["results"][0]["status"] == "duplicate"
    assert len(api.get("/favorites", headers=headers).json()) == 1


def test_sync_library_upsert_no_duplica(api, user_token):
    headers = _auth_headers(user_token)
    library_op = {
        "op_id": "op-library-0001",
        "type": "library_upsert",
        "data": {
            "public_id": "22222222-2222-2222-2222-222222222222",
            "ol_key": "/works/OL893414W",
            "title": "Dune",
            "author": "Frank Herbert",
            "status": "read",
        },
    }
    history_op = {
        "op_id": "op-history-0001",
        "type": "history_add",
        "data": {"id": "hist-1", "query": "dune"},
    }

    first = api.post(
        "/sync", json={"operations": [library_op, history_op]}, headers=headers
    )
    assert first.status_code == 200
    assert [r["status"] for r in first.json()["results"]] == ["applied", "applied"]

    retry = api.post(
        "/sync", json={"operations": [library_op, history_op]}, headers=headers
    )
    assert [r["status"] for r in retry.json()["results"]] == ["duplicate", "duplicate"]
    assert len(api.get("/library", headers=headers).json()) == 1
    assert len(api.get("/history", headers=headers).json()) == 1
