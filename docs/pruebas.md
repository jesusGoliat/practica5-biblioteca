# Plan y matriz de pruebas — Práctica 5 (Biblioteca ESCOM)

> Las secciones 1 y 2 (criterios y riesgos) y la estructura de la matriz se
> commitearon **antes** de ejecutar (commit `0a56210`). Los resultados de las
> secciones 3 a 7 se llenaron **después**, con ejecuciones reales. Un caso
> bloqueado no cuenta como ejecutado.

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

## 3. Entorno

| Campo | Valor |
|---|---|
| SHA base de referencia | `79c6cde` (último commit antes de la UI de la Práctica 5) |
| SHA probado | Primera pasada: `0a56210`. Correcciones y repetición de casos afectados: `b422309` y `7e038ca` (APK final). Commits posteriores: documentación, evidencias, CI de iOS y compatibilidad de iOS (`connectivity_plus` fijado en 7.0.0 y sin `Podfile` manual). |
| Autor de la ejecución | Jesús Ángel González Arellano (`jesusGoliat`), con asistencia de Claude Code para guiar el guion y tomar las capturas por `adb` |
| Fecha | 2026-11-05, 21:48 a 22:35 (hora del dispositivo) |
| Equipo de desarrollo | Linux, Flutter 3.47.6, JDK 21, Docker 29.8 / Compose |
| Android | Xiaomi 25062PC34G, Android 16 (API 36), conectado por USB, **sin emulador**; APK debug de la rama |
| iOS | Simulador iPhone en Codemagic (`mac_mini_m2`; respaldo: GitHub Actions `macos-15`). Resultados en la sección 8 |
| Backend | Docker Compose local (PostgreSQL 17, FastAPI), accesible desde el celular con `adb reverse tcp:8000 tcp:8000` |
| Datos | Cuentas ficticias `alumno1@`, `alumno2@` y `admin@biblioteca.test`; ninguna credencial real |

## 4. Resultados por caso

Estados: **aprobado**, **fallido**, **bloqueado** (no cuenta como ejecutado) o
**parcial** (se indica qué parte se ejecutó). Todas las capturas están en
`docs/img/android/`.

| ID | Resultado real (Android) | Estado | Evidencia | Defecto |
|---|---|---|---|---|
| P-01 | Registro e inicio de sesión correctos. Alta del libro, estado «Leyendo» y 4 estrellas llegaron al servidor (`reading`, `rating = 4`). La baja pide confirmación y deja `deleted = t` en el servidor. | Aprobado | [02](img/android/02-p01-registro-formulario.png) [03](img/android/03-p01-sesion-iniciada-buscar.png) [06](img/android/06-p01-favorito-biblioteca-calificacion.png) [27](img/android/27-p01-biblioteca-leyendo.png) [28](img/android/28-p01-confirmar-quitar-libro.png) · `evidencias/p01-baja-logica-en-servidor.txt` | — |
| P-02 | «dune»: 48 281 resultados en 0.8 s con portada, autor y año. El detalle trae descripción real de Open Library. | Aprobado | [04](img/android/04-p02-resultados-dune.png) [05](img/android/05-p02-detalle-dune.png) | — |
| P-03 | Sin resultados (`zzzzqqqxxyy`), credenciales incorrectas, servidor detenido (1 cambio pendiente y error visibles) y recuperación automática al reiniciar el servidor, sin cierres. La consulta nueva sin red y sin caché sólo se cubrió con la prueba automática (`repository_test.dart`), no en el dispositivo. | Aprobado (parcial en la sub-prueba indicada) | [13](img/android/13-p03-sin-resultados.png) [26](img/android/26-p03-login-credenciales-incorrectas.png) [29](img/android/29-p03-servidor-caido-pendientes.png) [30](img/android/30-p03-reintento-automatico-recupera.png) | D-08 (corregido) |
| P-04 | Android: «Continuar con Google» abrió el selector de cuenta, el backend validó el ID token y creó la cuenta `chuchisamtkd@gmail.com` (rol `user`, sin contraseña local). El perfil mostró nombre y correo de Google; la sesión se restauró al cerrar y abrir la app y el cierre de sesión volvió al login. **iOS: pendiente** (depende del workflow de CI y del client ID de iOS). | Aprobado en Android; iOS pendiente | [01](img/android/01-p04-login-inicial.png) [25](img/android/25-p04-google-no-configurado.png) (antes de configurar) · [36](img/android/36-p04-google-pantalla-1.png) [37](img/android/37-p04-google-sesion-iniciada.png) [38](img/android/38-p04-google-perfil.png) [39](img/android/39-p04-google-sesion-restaurada.png) [40](img/android/40-p04-google-cierre-de-sesion.png) · `evidencias/p04-google-usuario-en-servidor.txt` | D-10 (cerrado en Android) |
| P-05 | Tras cerrar la app por completo se abrió sin pedir login y el favorito siguió presente. | Aprobado | [07](img/android/07-p05-favoritos-tras-reinicio.png) | — |
| P-06 | Sin datos: 3 o más sugerencias populares con criterio. Con favoritos: criterio por temas. Se encontraron y corrigieron autores «desconocidos» y la imposibilidad de actualizar. | Aprobado (tras corregir) | Antes: [08](img/android/08-p06-recomendaciones-antes-autor-desconocido.png) · Después: [09](img/android/09-p06-recomendaciones-despues.png) | D-01, D-02 (corregidos) |
| P-07 | En modo avión la búsqueda mostró los resultados guardados con el banner «Sin conexión». Faltaba la fecha de los resultados guardados; se corrigió y se repitió. | Aprobado (tras corregir) | Antes: [10](img/android/10-p07-busqueda-sin-conexion.png) · Después: [31](img/android/31-p07-busqueda-sin-conexion-con-fecha.png) | D-06 (corregido) |
| P-08 | Sin red se marcó un favorito y se agregó un libro: «2 cambios pendientes» y el servidor sin cambios. Al reconectar sincronizó solo, el contador llegó a 0 y el servidor quedó con 2 libros y sin duplicados. El mismo `op_id` enviado dos veces dio `applied` y luego `duplicate`. | Aprobado | [11](img/android/11-p08-cambios-pendientes-sin-conexion.png) [12](img/android/12-p08-sincronizado-tras-reconexion.png) · `evidencias/sync-idempotencia-y-403.txt` | D-06 (error obsoleto tras reconectar, corregido) |
| P-09 | Segundo plano y regreso sin perder sesión ni datos; rotación a horizontal con diseño adaptado y estado conservado (consulta y resultados). | Aprobado | [32](img/android/32-p09-tras-segundo-plano.png) [33](img/android/33-p09-rotacion-horizontal-campo-limpio.png) [34](img/android/34-p09-rotacion-horizontal-con-resultados.png) | D-09 (limitación) |
| P-10 | La cuenta B no vio nada de la cuenta A (favoritos vacíos, sin insignia en Biblioteca); al volver con A sus favoritos y libros seguían. | Aprobado | [14](img/android/14-p10-perfil-cuenta-a.png) [15](img/android/15-p10-registro-cuenta-b.png) [16](img/android/16-p10-cuenta-b-favoritos-vacios.png) [17](img/android/17-p10-cuenta-a-datos-intactos.png) | — |
| P-11 | Con fuente 1.45 se recorrieron Perfil y Buscar: sin desbordes ni cortes salvo el título «Sincronización». Etiquetas y áreas táctiles verificadas con `uiautomator` (todas ≥ 48 dp). **TalkBack real no se ejecutó.** | Parcial (texto ampliado y etiquetas; sin TalkBack) | [22](img/android/22-p11-texto-ampliado-perfil.png) [23](img/android/23-p11-texto-ampliado-busqueda.png) · `evidencias/accesibilidad-p11-etiquetas-y-areas.txt` · Después: [35](img/android/35-perfil-version-final.png) | D-07 (corregido) |
| P-12 | `pytest`: 18 pruebas pasan, incluida `test_regression_tareas.py` (CRUD de `/tareas`). La app Kotlin de la Práctica 2 no se volvió a ejecutar. | Aprobado (sólo backend) | Salida de `pytest` (sección 5) | — |
| P-13 | El manifiesto principal tiene `usesCleartextTraffic="false"` y sólo el de debug lo habilita; la prueba `app_config_test.dart` confirma que release rechaza HTTP. No se instaló un APK release en el celular. | Parcial (verificación automática y estática) | `app/test/app_config_test.dart`, manifiestos Android | — |
| P-14 | Cuenta normal: HTTP 403 en `/admin/users` y sin panel en la app. Cuenta admin: lista de usuarios con contadores, historial y favoritos de `alumno1`. | Aprobado | [18](img/android/18-p14-admin-lista-usuarios.png) [19](img/android/19-p14-admin-detalle-historial.png) [20](img/android/20-p14-admin-detalle-favoritos.png) [21](img/android/21-p14-admin-despues-correccion.png) · `evidencias/sync-idempotencia-y-403.txt` | D-04, D-05 (corregidos) |

## 5. Pruebas automáticas

| Suite | Qué cubre | Resultado |
|---|---|---|
| `backend/tests` (pytest) | Auth, biblioteca, favoritos, historial, `/sync` idempotente, admin 403, regresión de tareas, contadores de admin | 18 pasan |
| `app/test` (flutter test) | Repositorio local-first (cola, caché, aislamiento por usuario, historial), fechas UTC, autores, candado HTTPS y validación del login | 15 pasan |
| `flutter analyze` | Análisis estático | Sin problemas |
| `integration_test/evidencia_test.dart` en simulador iOS | Recorrido con capturas (Codemagic; respaldo: GitHub Actions) | Ver sección 8 |

El mismo recorrido de integración se intentó en el Xiaomi con `flutter drive`, pero
quedó detenido en la primera captura (`convertFlutterSurfaceToImage`), por lo que
las capturas de Android se tomaron con `adb exec-out screencap` siguiendo los casos
manualmente. No es un defecto de la app.

## 6. Hallazgos

| ID | Defecto (pasos → esperado vs. observado) | Severidad | Estado | Evidencia |
|---|---|---|---|---|
| D-01 | Recomendaciones → cada libro decía «Autor desconocido». Open Library entrega los autores del endpoint de temas como objetos `{name}` y el modelo sólo leía textos. | Media: dato incompleto en una función principal | Corregido (`b422309`) | [08](img/android/08-p06-recomendaciones-antes-autor-desconocido.png) → [09](img/android/09-p06-recomendaciones-despues.png) |
| D-02 | Recomendaciones generadas al registrarse (sin datos) seguían diciendo «aún no tienes historial» con favoritos y no había forma de actualizarlas. | Media: criterio visible desactualizado | Corregido: botón «Actualizar» | [09](img/android/09-p06-recomendaciones-despues.png) |
| D-03 | Buscar escribiendo «zzzzqqqxxyy» → el historial guardó `zzzx`, `zzzz`, `zzzzq`… porque la búsqueda automática también registraba. Esperado: sólo la búsqueda confirmada. | Media: historial inservible | Corregido; prueba automática | [19](img/android/19-p14-admin-detalle-historial.png) |
| D-04 | Panel admin → «Favoritos: 3» cuando el usuario tenía 2; el contador incluía borrados lógicos. | Baja | Corregido; `test_admin.py` | [18](img/android/18-p14-admin-lista-usuarios.png) |
| D-05 | Panel admin → historial a las «04:10» cuando eran las 22:10 locales; el servidor envía UTC sin zona. | Media: fechas erróneas | Corregido; `server_date_test.dart` | [19](img/android/19-p14-admin-detalle-historial.png) → [21](img/android/21-p14-admin-despues-correccion.png) |
| D-06 | Sin red, los resultados guardados no mostraban su fecha; tras reconectar el aviso rojo de error seguía visible. | Baja | Corregido (leyenda de fecha y nueva consulta al sincronizar) | [10](img/android/10-p07-busqueda-sin-conexion.png), [12](img/android/12-p08-sincronizado-tras-reconexion.png) → [31](img/android/31-p07-busqueda-sin-conexion-con-fecha.png) |
| D-07 | Perfil con fuente 1.45 → «Sincronizaci / ón» se partía a media palabra por el botón lateral. | Baja (accesibilidad) | Corregido (`7e038ca`) | [22](img/android/22-p11-texto-ampliado-perfil.png) → [35](img/android/35-perfil-version-final.png) |
| D-08 | Error de login → «contrasena» sin ñ en el mensaje del servidor. | Baja | Corregido | [26](img/android/26-p03-login-credenciales-incorrectas.png) |
| D-09 | Horizontal con aviso de error → los banners ocupan casi toda la altura y sólo cabe un resultado. | Baja | **Pendiente** (limitación conocida, no se rediseña a última hora) | [34](img/android/34-p09-rotacion-horizontal-con-resultados.png) |
| D-10 | Inicio de sesión con Google sin probar por falta de client IDs de Google Cloud. | — (bloqueo externo) | **Cerrado en Android** tras crear los IDs; **pendiente en iOS** | [25](img/android/25-p04-google-no-configurado.png) → [37](img/android/37-p04-google-sesion-iniciada.png) |

## 7. Dictamen

Se recomienda entregar la versión `7e038ca` (más documentación). Con evidencia
real en un celular Android 16 quedaron aprobados el inicio de sesión con Google, la búsqueda pública, favoritos y
biblioteca persistentes, recomendaciones, modo sin conexión, sincronización sin
duplicados (también demostrada contra el backend), aislamiento entre cuentas, rol
de administrador con 403 y manejo de errores sin cierres. Se encontraron y
corrigieron 8 defectos; el comportamiento antes y después está en las capturas.

Riesgos que quedan: (1) Google Sign-In probado sólo en Android, no en iOS; (2) pruebas
de iOS sujetas a la ejecución del workflow (sección 8); (3) TalkBack real y APK
release no ejecutados; (4) D-09 en horizontal.

## 8. Resultados en iOS

_Se llenan con la ejecución de `codemagic.yaml` (o, como respaldo, de
`.github/workflows/ios.yml`); si no se logra ejecutar, se declara aquí como
bloqueado y no se reporta como probado._

## 9. Contribuciones y herramientas

- Autoría: Jesús Ángel González Arellano (`jesusGoliat`), integrante único.
- Herramientas de IA utilizadas: Claude Code (asistente de programación) para
  escribir código, pruebas y documentación y para guiar la ejecución de la
  matriz; las acciones en el dispositivo y la publicación del repositorio las
  realiza el autor.
