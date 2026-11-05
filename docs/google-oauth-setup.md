# Configuración de Google Sign-In (Práctica 5)

Esta guía crea las credenciales **públicas** de OAuth para Android, iOS y el backend.
No se sube ningún secreto al repositorio. Los *client IDs* no son secretos; los
*client secrets* de Google no se usan en esta práctica.

## 1. Crear el proyecto

1. Entra a <https://console.cloud.google.com/> con tu cuenta de Google.
2. Crea un proyecto llamado `practica5-biblioteca`.
3. Selecciónalo en la parte superior.

## 2. Pantalla de consentimiento

1. Ve a **APIs y servicios → Pantalla de consentimiento de OAuth**.
2. Tipo de usuario: **Externo**.
3. Nombre de la app: `Biblioteca ESCOM`.
4. Correo de asistencia: tu correo.
5. Datos de contacto del desarrollador: tu correo.
6. Permisos (scopes): `openid`, `email`, `profile` (no son sensibles).
7. En **Usuarios de prueba**, agrega la cuenta de Google con la que vas a demostrar
   el inicio de sesión. Mientras la app esté en modo **Testing**, solo esas cuentas
   pueden entrar.

## 3. Crear los tres client IDs

### 3.1 Web (obligatorio para el backend y para el `serverClientId`)

1. **APIs y servicios → Credenciales → Crear credenciales → ID de cliente de OAuth**.
2. Tipo: **Aplicación web**.
3. Nombre: `practica5-web`.
4. No necesitas orígenes ni URIs de redirección para el flujo móvil.
5. Guarda el **Client ID** (termina en `.apps.googleusercontent.com`).
   El *client secret* no se usa ni se comparte.

### 3.2 Android

1. Crea otro client ID, tipo **Android**.
2. Nombre: `practica5-android`.
3. **Nombre del paquete:** `mx.ipn.practica5.biblioteca`.
4. **Huella SHA-1 del keystore de debug:**
   `51:AD:00:A2:78:B9:C8:12:70:AB:2B:06:87:82:AE:D7:7B:B8:CA:0D`
   (se obtuvo con:
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1`).
   Si mañana se borra o se regenera el keystore, hay que actualizar esta huella.
5. No se necesita `google-services.json`: la app pasa el client ID **web** como
   `serverClientId` y Android valida el paquete + SHA-1 registrados aquí.

### 3.3 iOS

1. Crea otro client ID, tipo **iOS**.
2. Nombre: `practica5-ios`.
3. **Bundle ID:** `mx.ipn.practica5.biblioteca`.
4. Guarda el **Client ID** y su **client ID invertido**
   (por ejemplo `com.googleusercontent.apps.1234567890-abc...`).
5. En `app/ios/Runner/Info.plist` se configurarán:
   - `GIDClientID` = client ID de iOS.
   - `CFBundleURLSchemes` = client ID invertido.
   - `GIDServerClientID` = client ID web (opcional).

## 4. Dónde van los IDs (sin secretos en git)

### Backend (`backend/.env`, ignorado por git)

```dotenv
GOOGLE_CLIENT_IDS=WEB_ID,ANDROID_ID,IOS_ID
```

El backend acepta cualquiera de los tres como `aud` del ID token y valida
`email_verified` y el emisor de Google.

### App Flutter (`dart_defines.local.json`, ignorado por git)

Copia `dart_defines.example.json` a `dart_defines.local.json` y coloca:

```json
{
  "API_BASE_URL": "https://tu-tunel.trycloudflare.com",
  "GOOGLE_WEB_CLIENT_ID": "WEB_ID",
  "GOOGLE_IOS_CLIENT_ID": "IOS_ID"
}
```

Ejecuta:

```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

Para desarrollo local por USB también sirve
`"API_BASE_URL": "http://127.0.0.1:8000"` con `adb reverse tcp:8000 tcp:8000`.

## 5. Qué enviar al asistente

Solo los **tres client IDs** (web, Android e iOS) y confirma la cuenta que agregaste
como *test user*. No envíes contraseñas, tokens ni el *client secret*.

## 6. Si algo falla

- `clientConfigurationError` en Android: revisa el paquete, la SHA-1 y que
  `serverClientId` sea el client ID **web**.
- `-34018` en iOS: faltan los entitlements de Keychain (se configuran en el proyecto).
- `503 Google Sign-In no configurado`: falta `GOOGLE_CLIENT_IDS` en `backend/.env`
  o el backend no se reinició después de agregarlo.
