from conftest import _auth_headers


def test_payload_malformado_devuelve_422(api, user_token):
    headers = _auth_headers(user_token)
    response = api.post(
        "/library",
        json={"ol_key": "/works/OL1W", "title": "", "rating": 99},
        headers=headers,
    )
    assert response.status_code == 422

    response = api.post("/sync", json={"operations": "no-es-lista"}, headers=headers)
    assert response.status_code == 422


def test_sync_tipo_desconocido_reporta_error(api, user_token):
    headers = _auth_headers(user_token)
    response = api.post(
        "/sync",
        json={
            "operations": [
                {"op_id": "op-rara-0001", "type": "history_add", "data": {}}
            ]
        },
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["results"][0]["status"] == "error"
