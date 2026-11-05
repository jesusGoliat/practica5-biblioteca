from conftest import _auth_headers


def test_crud_tareas_practica2_sigue_funcionando(api, user_token):
    headers = _auth_headers(user_token)
    created = api.post(
        "/tareas",
        json={"titulo": "Regresión", "descripcion": "Práctica 2"},
        headers=headers,
    )
    assert created.status_code == 201, created.text
    tarea_id = created.json()["id"]

    assert len(api.get("/tareas", headers=headers).json()) == 1

    updated = api.put(
        f"/tareas/{tarea_id}", json={"completada": True}, headers=headers
    )
    assert updated.status_code == 200
    assert updated.json()["completada"] is True

    assert api.delete(f"/tareas/{tarea_id}", headers=headers).status_code == 200
    assert api.get("/tareas", headers=headers).json() == []
