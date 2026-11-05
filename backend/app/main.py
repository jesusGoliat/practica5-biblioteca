from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import init_db
from .routers import admin, auth, favorites, history, library, sync, tareas


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="Practica 5 - Biblioteca API",
    description=(
        "API REST de la Practica 5: autenticacion (correo/contrasena y Google), "
        "CRUD de libros, historial, favoritos, sincronizacion idempotente y rol "
        "administrador. Desarrollo de aplicaciones moviles nativas, ESCOM-IPN."
    ),
    version="2.0.0",
    lifespan=lifespan,
)

# Util para probar desde un navegador/Flutter web durante el desarrollo.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(tareas.router)
app.include_router(library.router)
app.include_router(favorites.router)
app.include_router(history.router)
app.include_router(sync.router)
app.include_router(admin.router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "practica5-biblioteca-api"}


@app.get("/health")
def health():
    return {"status": "ok", "service": "practica5-biblioteca-api"}
