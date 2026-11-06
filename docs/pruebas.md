# Plan y matriz de pruebas — Práctica 5 (Biblioteca ESCOM)

> Este documento se escribió **antes** de ejecutar las pruebas (ver historial de
> commits). Las columnas «Resultado real», «Estado» y «Evidencia» se llenan
> **sólo después** de ejecutar cada caso. Un caso bloqueado no cuenta como
> ejecutado.

## 1. Alcance y criterios de aceptación

| ID | Criterio de aceptación observable | Tipo |
|---|---|---|
| CA-1 | Con sesión iniciada, buscar «dune» muestra resultados reales de Open Library con portada, título y autor; el libro se puede marcar favorito y agregar a la biblioteca. | Éxito |
| CA-2 | Sin conexión, la app abre con la sesión validada y muestra búsquedas, favoritos, biblioteca y recomendaciones guardados; los cambios hechos sin red se envían una sola vez al recuperar la conexión (sin duplicados). | Alterno / límite |
| CA-3 | Una cuenta normal recibe 403 en `/admin/*` y no ve el panel; la cuenta administradora lista usuarios, historiales y favoritos. | Seguridad |
| CA-4 | Cada cuenta ve únicamente sus propios datos (historial, favoritos, biblioteca) en la app y en el backend. | Seguridad |

## 2. Riesgos

| ID | Riesgo | Impacto | Caso que lo cubre |
|---|---|---|---|
| R-1 | Reintentar un lote de `/sync` duplica favoritos, libros o historial. | Datos duplicados / pérdida de confianza | P-08, T-backend (`test_sync.py`) |
| R-2 | Una sesión ve datos de otra cuenta (caché o SQLite compartidos). | Fuga de información personal | P-10, `repository_test.dart` |
| R-3 | La descarga (pull) sobrescribe cambios locales aún no enviados. | Pérdida de cambios offline | P-08 |
| R-4 | Tráfico HTTP en release o secretos en el repositorio. | Incumple el enunciado (HTTPS, sin secretos) | P-13 |
| R-5 | JSON malformado o error de red cierra la app. | Cierre inesperado | P-03, `repository_test.dart` |
| R-6 | Google Sign-In sin client IDs correctos falla de forma poco clara. | Acceso bloqueado | P-04 |

## 3. Entorno (se completa al ejecutar)

| Campo | Valor |
|---|---|
| SHA base de referencia | `79c6cde` (último commit antes de la UI de la Práctica 5) |
| SHA probado | _pendiente_ |
| Autor de la ejecución | Jesús Ángel González Arellano (`jesusGoliat`) |
| Fecha | _pendiente_ |
| Equipo de desarrollo | Linux, Flutter 3.47.6, JDK 21, Docker Compose |
| Android | _pendiente: modelo, versión de Android/API (≥ 24), conexión por USB, sin emulador_ |
| iOS | Simulador iPhone en GitHub Actions `macos-15` (Xcode del runner; identificado en `dispositivo.txt`) |
| Backend | Docker Compose local (PostgreSQL 17) para Android; FastAPI + SQLite en el runner para iOS |
| Datos | Cuentas ficticias; ninguna credencial real |

## 4. Casos de prueba

Cobertura de categorías obligatorias: ruta feliz (P-01, P-02, P-05, P-06),
alterna/límite (P-03, P-07, P-08, P-09), regresión (P-12), navegación y estado
(P-09, P-10), accesibilidad (P-11), compatibilidad/entorno (P-13).

| ID | Escenario del enunciado | Criterio / riesgo | Plataforma | Pasos | Resultado esperado | Resultado real | Estado | Evidencia | Defecto |
|---|---|---|---|---|---|---|---|---|---|
| P-01 | Consulta REST (CRUD) | CA-1 | Android, iOS | 1. Registrar cuenta nueva. 2. Iniciar sesión. 3. Agregar un libro a la biblioteca. 4. Cambiar su estado a «Leyendo» y calificarlo. 5. Quitarlo. | Cada operación responde correctamente y la lista se actualiza. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-02 | Búsqueda pública | CA-1 | Android, iOS | 1. Buscar «dune». 2. Abrir el primer resultado. | Lista con portada/título/autor y tiempo de respuesta; detalle con descripción. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-03 | Estado vacío y error | R-5 | Android, iOS | 1. Buscar `zzzzqqqxxyy`. 2. Detener el backend y pulsar «Sincronizar ahora». 3. Con red apagada, buscar una consulta nueva. | Mensaje de «Sin resultados»; error de red visible y controlado; sin cierre de la app. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-04 | Acceso con Google y cierre de sesión | R-6 | Android, iOS | 1. Pulsar «Continuar con Google». 2. Cerrar sesión. 3. Reabrir la app. | Ingreso validado por el backend, sesión restaurada y cierre correcto. **Bloqueado** si faltan client IDs (se documenta, no se simula). | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-05 | Favoritos persistentes | CA-1 | Android, iOS | 1. Marcar dos libros como favoritos. 2. Cerrar la app por completo. 3. Abrirla. | Los favoritos siguen presentes. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-06 | Recomendaciones | — | Android, iOS | 1. Con cuenta sin datos, abrir «Para ti» y generar. 2. Agregar favoritos y regenerar. | Al menos 3 recomendaciones, criterio visible; caso sin historial resuelto con temas populares. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-07 | Consulta sin conexión | CA-2 | Android | 1. Buscar «dune» con red. 2. Activar modo avión. 3. Repetir la búsqueda y abrir Favoritos, Biblioteca y «Para ti». | Resultados guardados con su fecha; banner «Sin conexión»; datos locales accesibles. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-08 | Reconexión y sincronización sin duplicados | CA-2, R-1, R-3 | Android | 1. En modo avión marcar un favorito y agregar un libro. 2. Observar contador de pendientes. 3. Desactivar modo avión. 4. Revisar en el backend (`/favorites`, `/library`). | Los cambios se envían una vez, el contador llega a 0 y no hay duplicados; el cambio local no se pierde. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-09 | Reinicio de la aplicación | CA-2 | Android | 1. Con datos y sesión, cerrar y abrir la app (sin red). 2. Rotar el dispositivo / enviar a segundo plano y volver. | Sesión restaurada y datos visibles; estado conservado. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-10 | Aislamiento entre usuarios | CA-4, R-2 | Android, iOS | 1. Con la cuenta A crear favoritos. 2. Cerrar sesión e ingresar con la cuenta B. | B no ve datos de A; al volver con A sus datos siguen. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-11 | Accesibilidad | — | Android | 1. Texto del sistema al máximo: recorrer Buscar, Biblioteca y Perfil. 2. Con TalkBack, usar el botón de favorito y la navegación inferior. | Sin desbordes; los controles tienen etiqueta y área táctil suficiente. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-12 | Regresión de la Práctica 2 | — | Backend | Ejecutar `pytest` (incluye `test_regression_tareas.py`) y probar `/tareas` con la app de la Práctica 2. | CRUD de tareas sin cambios. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-13 | Compatibilidad y entorno | R-4 | Android, iOS | 1. Instalar el APK/IPA de release: confirmar que rechaza `http://` remoto. 2. Probar con otra red (hotspot) y revisar que el repositorio no contiene secretos. | Release exige HTTPS; sin secretos en `git`. | _pendiente_ | _pendiente_ | _pendiente_ | — |
| P-14 | Rol administrador y acceso denegado | CA-3 | Android, iOS, backend | 1. Cuenta normal: `GET /admin/users` (esperado 403) y comprobar que la app no muestra el panel. 2. Cuenta admin: abrir Perfil → Panel, ver historial y favoritos de un usuario. | 403 para cuenta normal; el administrador ve usuarios, historiales y favoritos. | _pendiente_ | _pendiente_ | _pendiente_ | — |

## 5. Pruebas automáticas (complementan, no sustituyen a las manuales)

| Suite | Qué cubre | Resultado |
|---|---|---|
| `backend/tests` (pytest) | Auth, CRUD de biblioteca, favoritos, historial, `/sync` idempotente, admin 403, regresión de tareas, validaciones | _pendiente de re-ejecutar en el SHA probado_ |
| `app/test` (flutter test) | Repositorio local-first (cola, caché, aislamiento por usuario) y validación del login | _pendiente_ |
| `app/integration_test/evidencia_test.dart` | Recorrido completo con capturas en simulador iOS | _pendiente (GitHub Actions)_ |

## 6. Hallazgos y dictamen

_Se completan tras la ejecución: cada defecto con pasos reproducibles, esperado vs.
observado, severidad justificada, evidencia, estado (corregido, preexistente o
pendiente) y su issue sin duplicar._

## 7. Contribuciones y herramientas

- Autoría: Jesús Ángel González Arellano (`jesusGoliat`), integrante único.
- Herramientas de IA utilizadas: Claude Code (asistente de programación) para
  escribir y revisar código y documentación; la ejecución de pruebas en
  dispositivos y la publicación del repositorio las realiza el autor.
