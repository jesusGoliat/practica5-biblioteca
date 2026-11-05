"""Sincronización por lote con idempotencia por `op_id`.

El cliente puede reintentar el mismo lote sin duplicar datos: la primera
aplicación guarda el resultado en SyncOperation y los reintentos lo repiten.
"""

import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlmodel import Session

from ..database import get_session
from ..models import SyncOperation, User
from ..schemas import SyncBatch, SyncBatchResult, SyncOperationIn, SyncOperationResult
from ..security import get_current_user
from .favorites import apply_favorite_set
from .history import apply_history_add
from .library import apply_library_delete, apply_library_upsert

router = APIRouter(prefix="/sync", tags=["sync"])


def _dispatch(session: Session, user: User, op: SyncOperationIn) -> dict:
    if op.type == "favorite_set":
        return apply_favorite_set(session, user, op.data)
    if op.type == "library_upsert":
        return apply_library_upsert(session, user, op.data)
    if op.type == "library_delete":
        return apply_library_delete(session, user, op.data)
    if op.type == "history_add":
        return apply_history_add(session, user, op.data)
    raise ValueError(f"Tipo de operacion desconocido: {op.type}")


@router.post("", response_model=SyncBatchResult)
def sincronizar(
    payload: SyncBatch,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    results: list[SyncOperationResult] = []

    for op in payload.operations:
        previous = session.get(SyncOperation, op.op_id)
        if previous is not None and previous.user_id == user.id:
            results.append(
                SyncOperationResult(
                    op_id=op.op_id,
                    status="duplicate",
                    result=json.loads(previous.result_json or "{}"),
                )
            )
            continue

        try:
            # Savepoint por operación: un fallo no tumba las demás.
            with session.begin_nested():
                result = _dispatch(session, user, op)
                record = SyncOperation(
                    op_id=op.op_id,
                    user_id=user.id,
                    type=op.type,
                    status="applied",
                    result_json=json.dumps(result, default=str),
                    applied_at=datetime.now(timezone.utc),
                )
                session.add(record)
                session.flush()
            results.append(
                SyncOperationResult(op_id=op.op_id, status="applied", result=result)
            )
        except Exception as exc:  # noqa: BLE001 - se reporta por operación
            results.append(
                SyncOperationResult(op_id=op.op_id, status="error", detail=str(exc))
            )

    session.commit()
    return SyncBatchResult(
        results=results,
        server_time=datetime.now(timezone.utc),
    )
