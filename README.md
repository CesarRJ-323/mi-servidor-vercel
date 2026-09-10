# RAPIDIYA — App de Delivery Huperlocal

Aplicación Flutter de delivery para Android/iOS. Conectada a Firebase (Firestore, Auth, Functions, AppCheck, Messaging).

## Project ID (Firebase)

```
PRODUCTION:  deliverymovile-c25ff
EMULATOR:    deliverymovile-c25ff (mismo project ID)
```

## Estructura rápida

```
C:/Users/lia/Desktop/delivery_app_v2/
├── android/               # Config Android nativo
│   ├── app/google-services.json  ← Firebase config (NO MODIFICAR)
│   └── key.properties      ← Credenciales release keystore
├── lib/
│   ├── main.dart          ← Entry point: detecta kDebugMode → emulador
│   ├── data/repositories/ # Firestore repos (promo, auth, productos, pedidos)
│   ├── models/            # Promo, Usuario, Producto, CarritoItem, Pedido
│   ├── screens/           # UI screens (home, login, cart, admin, sorteos)
│   └── services/          # ServerRateLimiter, PrecioService, FCM
├── firebase.json          ← Emulador config (ports, rules)
├── firestore.rules        ← Security rules
├── functions/src/index.js ← Cloud Functions (rateLimit, MP webhooks)
└── scripts/               ← Seed scripts (seed_admin.js)
```

## ⚠️ REGLAS DE ORO (para cualquier IA)

1. **main.dart línea 28-36**: `if (kDebugMode)` → activa emuladores. En `release`/`profile`, apunta a Firestore/Auth/Functions **PROD**. NUNCA hardcodear emuladores fuera de este `if`.

2. **Firestore Rules** (`firestore.rules`):
   - **DEV (emulador)**: `allow read, write: if true` (todo abierto, AppCheck relax)
   - **PROD**: requiere `request.auth != null` + `appCheckValida()` en writes admin

3. **AppCheck**: `AndroidProvider.debug` en debug. `PLAY_INTEGRITY` en release.

4. **Rate limiter server-side** (`functions/src/index.js`):
   - `rateLimit` callable: en emulador, `enforceAppCheck = false` (para testing)
   - En prod, AppCheck es obligatorio
   - Cliente (`ServerRateLimiter.check`): fail-open en debug si la function falla

## Emuladores (solo desarrollo)

| Servicio    | Puerto | Host         |
|-------------|--------|--------------|
| Firestore   | 8383   | 127.0.0.1    |
| Auth        | 9191   | 127.0.0.1    |
| Functions   | 5222   | 127.0.0.1    |
| Hub         | 4777   | 127.0.0.1    |

Android emulador (10.0.2.2) mapeado a 127.0.0.1 por Flutter automáticamente.

```bash
# Levantar emuladores
firebase emulators:start --only firestore,auth,functions

# Seedear datos de testing (emulador)
FIRESTORE_EMULATOR_HOST=127.0.0.1:8383 node scripts/seed_admin.js
```

## Build de release

```bash
# Key store configurado en android/key.properties:
#   storeFile=C:/Users/lia/keystore/rapidiya-release-key.jks
#   storePassword=*** (ver key.properties)
#   keyAlias=rapidiya

flutter build apk --release  # → build/app/outputs/flutter-apk/app-release.apk
```

## 🔒 Credenciales (NO compartir en código)

| Archivo                          | Path                              |
|----------------------------------|-----------------------------------|
| Release keystore                 | C:/Users/lia/keystore/rapidiya-release-key.jks |
| Key properties (passwords)       | C:/Users/lia/Downloads/rapidiya-key.properties |
| Firebase config                  | android/app/google-services.json  |

## Troubleshooting rápido

| Síntoma                         | Causa                          | Fix                          |
|---------------------------------|--------------------------------|------------------------------|
| "Ocurrió un error. Intentá de nuevo." en login | Functions emulator caído | Ver `rateLimit` en `functions/src/index.js` — `isEmulator` check |
| Banner promos aparece pero con datos fake | App en emulador vacío | Verificar `kDebugMode` en `main.dart` — en release usa prod |
| Productos no aparecen en home   | Rules de Firestore en prod bloquean reads no-auth | Login requerido, scope `request.auth != null` |
| `GeneratedPluginRegistrant.java` error en release | `integration_test` en `GeneratedPluginRegistrant` | Remover `IntegrationTestPlugin` de registrator |

## Deploy prod

⚠️ Antes de subir a Play Store:
1. RE-AGREGAR `appCheckValida()` a writes admin en `firestore.rules`
2. AppCheck: cambiar de `AndroidProvider.debug` a `AndroidProvider.playIntegrity`
3. Cloud Function MP webhook (`processMPWebhook`) configurada con webhook real
4. Verificar índices compuestos en Firestore console
5. Cambiar `kReleaseMode` checks en `main.dart` (ya no usa emuladores)
