# Informe técnico — Práctica 5: Biblioteca ESCOM

Jesús Ángel González Arellano · Grupo 7CV4 · Desarrollo de aplicaciones móviles nativas · Prof. Gabriel Hurtado Avilés

---

## 1. Introducción

La práctica extiende la aplicación CRUD de la Práctica 2 (FastAPI + PostgreSQL +
cliente Kotlin/Compose) a una aplicación **Flutter** que funciona en Android e iOS
con un único código de cliente. Agrega consulta de una API pública (Open Library),
caché y base de datos local, sincronización con cola de operaciones, historial,
favoritos, recomendaciones verificables, inicio de sesión con Google y un rol de
administrador validado en el backend. Se conserva el historial de la Práctica 2
(etiqueta `practica2-base`, commit `1f4e511`).

## 2. Arquitectura

```text
┌────────────────────────── Flutter (Android + iOS, un solo código) ───────────────────────────┐
│ screens/  →  providers/ (ChangeNotifier)  →  data/Repository  →  core/db (SQLite, por user) │
│                                                       │  └─ core/network: BackendApi (Dio)   │
│                                                       │               OpenLibraryApi (Dio)   │
└───────────────────────────────────────────────────────┼──────────────────────────────────────┘
                                   HTTPS (release)      ▼
                         FastAPI (JWT, Argon2, Google ID token)  ──  PostgreSQL
                                   │
                                   └─ /sync idempotente por op_id
```

| Capa | Componentes | ¿Común o específico de plataforma? |
|---|---|---|
| Interfaz | `screens/`, `widgets/` (Material 3, es-MX) | Común |
| Estado | `providers/` (`provider`) | Común |
| Datos | `data/repository.dart`: caché, cola, sync, recomendaciones | Común |
| Persistencia | `sqflite` (SQLite), `flutter_secure_storage` (Keychain/Keystore) | Común (implementación nativa por plataforma) |
| Red | `dio` (cliente HTTP) | Común |
| Google Sign-In | `google_sign_in` 7.x | Configuración propia: Android (SHA-1 + client ID web) e iOS (client ID iOS + URL scheme) |
| Ajustes nativos | `AndroidManifest.xml` (cleartext sólo debug), `Info.plist` (ATS, GID*) | Específico |

## 3. Endpoints utilizados

Reutilizados de la Práctica 2: `POST /auth/register`, `POST /auth/login`,
`GET|POST|PUT|DELETE /tareas` (se conservan como regresión).

Añadidos en la Práctica 5:

| Método y ruta | Uso |
|---|---|
| `POST /auth/google` | Valida el ID token de Google en el backend y emite el JWT propio |
| `GET /auth/me`, `POST /auth/logout` | Restaurar y cerrar sesión |
| `GET/POST /library`, `PUT/DELETE /library/{public_id}` | CRUD de libros guardados (soft-delete, UUID cliente) |
| `GET /favorites`, `PUT /favorites` | Favoritos por usuario |
| `GET/POST/DELETE /history` | Historial de búsquedas por usuario |
| `POST /sync` | Lote idempotente de operaciones pendientes |
| `GET /admin/users`, `/admin/users/{id}/history|favorites|library` | Sólo administrador (403 para otros) |

API pública: Open Library (`/search.json`, `/works/{key}.json`,
`/subjects/{tema}.json`, portadas en `covers.openlibrary.org`).

## 4. Modelo de datos y persistencia

SQLite local (`biblioteca_practica5.db`), todas las tablas personales con `user_id`:

| Tabla | Contenido |
|---|---|
| `books` | Libros vistos (JSON + temas) para detalle y recomendaciones sin red |
| `search_cache` | Respuesta de cada búsqueda y su `fetched_at` |
| `search_history` | Historial por usuario (`id`, `op_id`, `synced`) |
| `favorites`, `library_items` | Datos del usuario con banderas `dirty` y `deleted` |
| `pending_ops` | Cola de operaciones (`op_id` UUID, tipo, carga, intentos, último error) |
| `recommendations` | Última recomendación generada, para verla sin red |
| `sync_state` | Última sincronización y último error |

Qué permanece accesible al cerrar y volver a abrir: la sesión (token y usuario en
almacenamiento seguro), y todo lo anterior en SQLite.

## 5. Autenticación y roles

- Registro/inicio con correo y contraseña (Argon2 en el servidor, JWT con rol).
- Google: el cliente obtiene el ID token con `google_sign_in`; el backend lo valida
  con `google-auth` contra los client IDs configurados y emite su propio JWT. Los
  tokens se guardan sólo en `flutter_secure_storage`.
- Sin conexión se restaura la sesión ya validada; no se exige Google sin red.
- El rol se lee **de la base de datos** en cada petición `/admin/*`; la interfaz
  sólo oculta el panel, pero la autorización real está en el backend (403).

## 6. Sincronización y conflictos

1. Toda escritura va primero a SQLite (`dirty = 1`) y se encola en `pending_ops`
   con un `op_id` UUID.
2. Se sincroniza al abrir, al recuperar conexión (`connectivity_plus`), tras cada
   cambio y manualmente; ante errores se reintenta con retroceso exponencial
   (5 s hasta 5 min). La interfaz muestra pendientes, última actualización y error.
3. **Push → pull.** `POST /sync` aplica cada operación en un *savepoint* y guarda
   su resultado por `op_id`; reenviar el mismo lote responde `duplicate` y no
   vuelve a aplicar nada, de modo que un reintento tras un corte no duplica datos.
4. Después se descargan biblioteca, favoritos e historial. **Prioridad:** una fila
   local con cambios pendientes (`dirty = 1`) nunca se sobrescribe; el resto adopta
   la versión del servidor. Entre dos cambios sobre el mismo registro gana la
   última operación que llega al servidor, aplicada en el orden de creación local.
5. Las bajas son lógicas (`deleted`) para que otro dispositivo las reciba.

## 7. Recomendaciones

Regla reproducible, sin modelo de IA: se pesan los temas (`subject`) de los libros
en favoritos (peso 2) y biblioteca (peso 1); se toman los tres temas más
frecuentes; si faltan, las palabras de las últimas búsquedas; si no hay datos,
temas populares (`fiction`, `science`, `history`). Para cada tema se consultan
obras de Open Library, se excluyen las que el usuario ya tiene y cada sugerencia
guarda el motivo que se muestra en pantalla. Se persisten para consultarlas sin red.

## 8. Resultados

La matriz completa está en [`pruebas.md`](pruebas.md). En un Xiaomi 25062PC34G con
Android 16 (API 36) se ejecutaron los casos P-01 a P-11 y P-14 (todos aprobados); P-12 y P-13 se verificaron con las pruebas automáticas y la revisión de los manifiestos. Google Sign-In se probó
de punta a punta. Resultados destacados:

- Búsqueda pública: 48 281 resultados en 0.8 s con portada, autor y año; detalle con
  descripción real.
- Sin conexión: resultados guardados con su fecha, favoritos y biblioteca locales.
- Sincronización: dos cambios hechos en modo avión quedaron como pendientes, se
  enviaron una sola vez al reconectar y el servidor quedó sin duplicados; reenviar el
  mismo `op_id` devolvió `duplicate`.
- Servidor caído: error visible, cambio pendiente y recuperación automática con los
  reintentos al volver el servidor.
- Seguridad: la cuenta normal recibió 403 en `/admin/users`; cada cuenta vio sólo sus
  datos.
- Se encontraron y corrigieron 8 defectos durante las pruebas (ver sección 6 de
  `pruebas.md`), con capturas del antes y el después.
- Automáticas: 18 pruebas del backend y 15 de Flutter, más `flutter analyze` limpio.

Resultados de iOS: ver la sección 8 de `pruebas.md`.

## 9. Conclusiones

La parte más delicada fue la sincronización: guardar una copia local es sencillo,
pero decidir qué ocurre con los cambios hechos sin red exige identificadores del
cliente, una cola reenviable sin duplicar y una regla clara de conflictos. Aislar esa
lógica en un repositorio local-first permitió probarla con SQLite en memoria sin
dispositivo. Las pruebas guiadas en un celular real encontraron defectos que las
pruebas automáticas no veían (autores faltantes, fechas desfasadas por la zona
horaria, historial con fragmentos tecleados), por lo que ambas son necesarias.

## 10. Herramientas de IA utilizadas

Claude Code (Anthropic) se usó como asistente para escribir y revisar código,
pruebas y documentación. Las decisiones de diseño, la ejecución de pruebas en
dispositivos y la publicación en GitHub fueron del autor.

## Referencias (APA)

Flutter. (s. f.). *Flutter documentation*. https://docs.flutter.dev/

FastAPI. (s. f.). *FastAPI*. https://fastapi.tiangolo.com/

Internet Archive. (s. f.). *Open Library API*. https://openlibrary.org/developers/api

Google. (s. f.). *Google Sign-In for Flutter (google_sign_in)*. https://pub.dev/packages/google_sign_in

SQLite Consortium. (s. f.). *SQLite documentation*. https://www.sqlite.org/docs.html
