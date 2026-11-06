# Guion de exposición (máximo 10 minutos)

| Min | Qué decir y mostrar |
|---|---|
| 0:00–1:00 | **Objetivo y alcance.** App Flutter única para Android e iOS sobre el backend FastAPI de la Práctica 2 (etiqueta `practica2-base`). Mostrar la estructura del repositorio. |
| 1:00–2:30 | **Código compartido y componentes por plataforma.** Compartido: `lib/` completo (pantallas, `provider`, repositorio, `dio`, `sqflite`). Específico: manifiesto Android (cleartext sólo en debug), `Info.plist`/`Podfile` de iOS, configuración de Google (SHA-1 en Android, client ID y URL scheme en iOS). |
| 2:30–5:30 | **Demo en Android (celular físico).** Registro → buscar «dune» → detalle → favorito y biblioteca → cerrar y abrir la app (persistencia) → «Para ti» con el criterio y «Actualizar». |
| 5:30–7:30 | **Sin conexión y sincronización.** Modo avión → búsqueda guardada con su fecha → marcar un favorito → contador de pendientes → quitar el modo avión → sincroniza sin duplicados. Mostrar `docs/evidencias/sync-idempotencia-y-403.txt` (`applied` y luego `duplicate`). |
| 7:30–8:30 | **Seguridad y administrador.** Cuenta B sin datos de A; cuenta admin con el panel; 403 de una cuenta normal (validado en el backend, no sólo oculto en la UI). |
| 8:30–9:15 | **iOS.** Mostrar las capturas del simulador iPhone Air generadas en Codemagic (búsqueda, detalle, recomendaciones y panel de administración) y la verificación de roles 403/200. |
| 9:15–10:00 | **Calidad y cierre.** 18 + 15 pruebas automáticas, 14 casos en dispositivo, 8 defectos encontrados y corregidos con antes/después (issues en GitHub) y uso de Claude Code. |

Antes de exponer: backend arriba (`docker compose up -d`), `adb reverse tcp:8000 tcp:8000`,
app instalada, modo avión desactivado y datos de las cuentas de prueba creados.
