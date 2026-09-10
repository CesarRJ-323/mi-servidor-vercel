# Plan de Solución: Firebase Connection + Admin Role Issues

## 🎯 Resumen de Problemas

### 🔴 Problema 1: App Check NullPointerException
**Síntoma:** `firebase_app_check/unknown: Attempt to invoke virtual method ... on a null object reference`

**Root cause:** `main.dart` línea 38-44 usa `providerAndroid` (deprecated/invalid parameter)
junto con `AndroidDebugProvider(debugToken: '...')` que causa NPE.

**Fix aplicado:** ✅
- Eliminé `providerAndroid` y el `debugToken` hardcodeado
- Dejé solo `androidProvider: AndroidProvider.debug` (el provider debug AUTO-genera
  el token y lo loggea, no se necesita injectarlo manualmente)

### 🔴 Problema 2: Firestore Rules regresionadas (CRÍTICO)
**Síntoma:** `Write failed at usuarios/{uid}: PERMISSION_DENIED`

**Root cause:** Las rules PUBLICADAS en Firebase Console son las viejas que:
- CREATE en usuarios exige `created_at` y `updated_at` → pero el modelo escribe `creado_en`
- No tienen `match /pedidos/` → todos los pedidos son DENY
- Sorteo participation requiere `esAdmin()` → clientes no pueden unirse

**Fix aplicado:** ✅
- Reescribí `firestore.rules` con las reglas endurecidas correctas
- Incluye field name alignment (`creado_en`, `usuario_id`)
- Agregué whitelist en usuarios update
- Agregué sorteo participation con safe-append pattern
- Quité `appCheckValida()` de usuarios read/update (clientes no tienen token debug registrado)

### 🟡 Problema 3: Composite index (parcialmente hecho)
**Síntoma:** `The query requires an index` para sorteos

**Status:** ✅ Ya creaste el índice en Console → muestra "Compilando..."
- Una vez "Enabled", las queries de sorteos funcionan
- El índice era para: `terminado` ASC + `fecha_fin` ASC + `__name__` ASC

### 🟡 Problema 4: Debug token no registrado (posible)
**Root cause del "admin entra como usuario":**
- Login con FirebaseAuth funciona ✅
- Pero al leer `usuarios/{uid}` para chequear el rol → PERMISSION_DENIED ❌
- `usuarioActualProvider` falla → `esAdmin` = false → trata como cliente
- "Mi cuenta" también falla → no se puede navegar

### 🟡 Problema 5: iOS/macOS firebase_options usa Android appId
- `firebase_options.dart` tiene appId android en iOS/macOS options
- No afecta Android, pero iOS no va a inicializar Firebase bien

---

## 📋 PLAN DE ACCIÓN (PASOS QUE DEBES EJECUTAR)

### PASO 1: Publicar Firestore Rules en Firebase Console (🔴 CRÍTICO)

1. Abrí [Firebase Console](https://console.firebase.google.com/)
2. Proyecto: `deliverymovile-c25ff`
3. Firestore → **Rules** (Reglas)
4. **Reemplazá TODO** el contenido con lo que está en:
   `C:\Users\lia\Desktop\delivery_app_v2\firestore.rules`
5. Click en **"Publish"**

> ⏱️ Después de published, las rules se aplican al instante. No necesitás rebuild.

### PASO 2: Verificar debug token de App Check

1. Firebase Console → **App Check** → tu app
2. Click en **"Manage debug tokens"** o la pestaña Debug tokens
3. Verificá que el token `0bad5d24-3de2-414a-9c4c-a63cf0b45b9a` esté en la lista
   - Si no está: el token es GENERADO AUTOMÁTICAMENTE por `AndroidProvider.debug`
     y aparece en logcat con el mensaje: `Allow debug token: <UUID>`
   - Buscalo en logcat después de correr la app: `adb logcat | grep "debug secret"`
4. Si no está registrado → agregalo

### PASO 3: Verificar composite index está "Enabled"

1. Firebase Console → Firestore → **Indexes** → **Composite**
2. Buscá el índice de `sorteos`: `terminado` ↑ + `fecha_fin` ↑ + `__name__` ↑
3. Debe decir **"Enabled"** (no "Compiling...")

### PASO 4: Rebuild + reinstall app

```bash
cd C:\Users\lia\Desktop\delivery_app_v2
flutter clean
flutter pub get
flutter install -d emulator-5554
```

### PASO 5: Login como admin

1. Abrir la app en el emulador
2. Login con: `alegandraaraoz@gmail.com` / [tu password]
3. La app debería detectar el rol admin ← leyendo `usuarios/{uid}.rol`

### PASO 6: Verificación

| Action | Expected | Cómo verificar |
|--------|----------|----------------|
| Login admin → Home | Ve productos/sorteos reales | La home ya no es mock |
| Click "Mi cuenta" | Muestra nombre, email, dirección | No tira PERMISSION_DENIED |
| Admin panel | Ve "Delivery Local" + "Resumen" | No tira permission-denied en pedidos |
| Abrir sorteo | Puede participar | Transaction OK, uid agregado a participantes |
| Crear pedido | Se guarda en Firestore | No sale error de permiso |
| FCM token | Se guarda en usuarios/{uid} | Ver en Console |

---

## 🚀 Alternativa: Deploy via Firebase CLI (si preferís automatizar)

Si preferís no hacer clic manual en el Console, podés instalar el CLI y hacerlo por comandos:

```bash
# 1. Login (abre browser)
firebase login

# 2. Deploy rules (usa el firestore.rules local)
firebase deploy --only firestore:rules --project deliverymovile-c25ff

# 3. Deploy indexes
firebase deploy --only firestore:indexes --project deliverymovile-c25ff
```

> **Nota:** Las Storage rules, Functions, y Hosting no se deployan con esos comandos.

---

## 📁 Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/main.dart` | ✅ Quitado `providerAndroid` + `debugToken` hardcodeado |
| `firestore.rules` | ✅ REESCRITO con reglas endurecidas corregidas |
| `storage.rules` | ✅ Mejorada con App Check validation |
| `SECURITY_AUDIT.md` | ✅ Generado (reporte completo) |
| `SEGURIDAD.md` | ✅ Actualizado |
| `deploy-firebase-fix.sh` | ✅ Script de deploy (para vos) |

---

## ❓ Qué hacer si después de todo esto sigue fallando

1. **Chequear logcat** por errores nuevos:
   ```bash
   adb logcat | grep -iE "firebase|permission|error|appcheck"
   ```
2. **Test REST directo** para aislar el problema:
   ```bash
   curl -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=<api_key>" \
     -d '{"email":"alegandraaraoz@gmail.com","password":"<password>"}'
   ```
3. Si `operation-not-allowed` → **Authentication → Sign-in method → Email/Password → Enable**

---
