# 🔐 Security Audit Report — Delivery App V2

**Project:** `delivery_app_v2` (Rapidiya)  
**Date:** 2026-09-03  
**Project ID:** `deliverymovile-c25ff`  
**Package:** `com.cesar.delivery_app`  
**Auditor:** Lia V2 (Hermes Agent)  
**Scope:** Full codebase security analysis — Firebase Auth, Firestore rules, Storage rules, App Check, Cloud Functions, model/Rules field-name alignment, credential hygiene, Mercado Pago integration, and more.

---

## 📊 Executive Summary

| Area | Status | Risk |
|------|--------|------|
| Firestore Rules | ⚠️ **CRITICAL regressions found** | High |
| Firebase Config | ✅ Healthy | Low |
| Auth & Rol Management | ✅ Hardened | Low |
| App Check | ✅ Configured + activated | Low |
| Credential Hygiene | ✅ Demo creds via dart-define | Low |
| Cloud Functions | ⚠️ Missing auth check | Medium |
| Mercado Pago | ⚠️ No webhook (pending prod) | Medium |
| Storage Rules | ✅ Hardened | Low |
| Git/VCS | ⚠️ No git repo yet | Low |

**Overall Security Posture: ⚠️ MODERATE-HIGH** — The project had strong security hardening (committed 31-Aug) that was **partially rolled back** in the current `firestore.rules`. Multiple critical collections (`pedidos`, sorteo participation) are currently **non-functional** because the rules deny all access. The backup at `backup_20260902_0149/firestore.rules` contains the **correct, hardened rules** — they must be republished.

---

## 🔴 CRITICAL FINDINGS

### 1. `firestore.rules` — `pedidos` collection has NO rules (CRITICAL)

**File:** `firestore.rules` (current, lines 63-64)  

The current `firestore.rules` has **no `match /pedidos/{id}` block**. The only fallback is:
```javascript
match /{document=**} { allow read, write: if false; }
```

**Impact:** `pedidos` collection is completely locked down — **nobody** (not even admin) can read or write pedidos. The admin dashboard (`admin_dashboard.dart`) calls `pedidosAdminStreamProvider` which reads from `pedidos`, and `PedidoRepository` writes new pedidos. All of these will fail with `permission-denied`.

**Root cause:** The current rules are a regression from the hardened version in `backup_20260902_0149/firestore.rules`, which had full pedidos rules.

**Fix:** Copy the pedidos rules from the backup:
```javascript
match /pedidos/{id} {
  allow read: if esAdmin()
    || (request.auth != null && resource.data.usuario_id == request.auth.uid);
  allow create: if request.auth != null
    && request.resource.data.usuario_id == request.auth.uid
    && request.resource.data.total is number
    && request.resource.data.total >= 0
    && request.resource.data.estado == 'pendiente';
  allow update: if esAdmin()
    || (request.auth != null
        && resource.data.usuario_id == request.auth.uid
        && resource.data.estado == 'pendiente'
        && request.resource.data.usuario_id == resource.data.usuario_id
        && !request.resource.data.diff(resource.data).affectedKeys().hasAny(
            ['estado_pago', 'pago_verificado', 'payment_id']));
  allow delete: if esAdmin();
}
```

---

### 2. `firestore.rules` — Sorteo participation rules removed (CRITICAL)

**File:** `firestore.rules` (current)  

The current rules for sorteos only allow:
```javascript
allow update: if esAdmin() && appCheckValida();
```

**Impact:** Regular users **cannot join sorteos**. The `SorteoRepository.participar()` method uses a Firestore transaction to append the user's `uid` to the `participantes` array, but this write is now denied because the rule requires admin.

**Root cause:** The hardened backup rules had a client-side participation branch:
```javascript
allow update: if esAdmin()
  || (request.auth != null
      && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['participantes', 'nombres_participantes'])
      && request.resource.data.participantes is list
      && request.resource.data.participantes.size() == resource.data.participantes.size() + 1
      && request.resource.data.participantes[resource.data.participantes.size() - 1] == request.auth.uid);
```

**Fix:** Restore the client participation branch in sorteos rules.

---

### 3. `firestore.rules` — `usuarios/{uid}` CREATE rule field mismatch (CRITICAL)

**File:** `firestore.rules` (current, line ~25)

The CREATE rule requires:
```javascript
request.resource.data.keys().hasAll(['email', 'rol', 'tokens_balance', 'created_at', 'updated_at'])
```

But the model (`Usuario.toJson()` in `lib/models/usuario_model.dart`) writes:
- `uid`, `nombre`, `email`, `telefono`, `direccion`, `maps_url`, `descripcion_casa`, `tokens_balance`, `rol`, `url_foto`, `creado_en`

**Missing:** `created_at` and `updated_at` are NOT written by the model.  
**Extra:** `nombre`, `telefono`, `direccion`, `maps_url`, `descripcion_casa`, `creado_en`, `url_foto` are written but not in the `hasAll()` list.

**Impact:** `hasAll()` requires ALL listed keys to be present. Since `created_at` and `updated_at` are never written, **user registration will fail** with permission-denied.

**Fix:** Change the rule to require `creado_en` instead of `created_at`/`updated_at`, and remove the `hasAll()` requirement or align it to what the model actually writes.

---

### 4. `firestore.rules` — Descuentos write validation lost (MEDIUM)

**File:** `firestore.rules` (current)

The current rules have **no validation** on descuentos writes:
```javascript
allow create: if esAdmin() && appCheckValida();
```

The backup had proper validation:
```javascript
allow write: if esAdmin()
  && request.resource.data.porcentaje is number
  && request.resource.data.porcentaje >= 0
  && request.resource.data.porcentaje <= 100;
```

**Impact:** An admin (or anyone who bypasses App Check) could write invalid discount values (>100%, <0%, non-numeric) causing price calculation bugs or negative prices.

**Fix:** Restore the `porcentaje` validation.

---

### 5. `firestore.rules` — Usuarios update missing field whitelist (HIGH)

**File:** `firestore.rules` (current)

The current usuarios update rule:
```javascript
allow read, update: if request.auth != null && request.auth.uid == uid
  && request.resource.data.rol == resource.data.rol
  && request.resource.data.tokens_balance >= resource.data.tokens_balance
  && request.resource.data.updated_at == request.time;
```

**Impact:** While `rol` and `tokens_balance` are protected, **any other field** can be updated by the user — including `latitud`, `longitud`, `url_foto`, etc. The backup rules had a whitelist:
```javascript
request.resource.data.diff(resource.data).affectedKeys().hasOnly(
  ['nombre', 'telefono', 'whatsapp', 'direccion', 'maps_url', 'descripcion_casa', 'url_foto'])
```

**Fix:** Add the `affectedKeys().hasOnly(...)` whitelist.

---

## 🟡 HIGH FINDINGS

### 6. `key.properties` — Keystore password in plaintext (HIGH)

**File:** `key.properties`

```properties
storeFile=C:/Users/lia/keystore/rapidiya-release-key-v2.jks
storePassword=Rapidiya_2026_K3y!V3rified
keyAlias=rapidiya
keyPassword=Rapidiya_2026_K3y!V3rified
```

**⚠️ Status:** The `.gitignore` ✅ DOES include `key.properties` — it is NOT committed to VCS. This is acceptable for a local dev environment, but:

**Recommendations:**
- Use a CI/CD secret manager for production builds (GitHub Actions secrets, GitLab CI variables)
- Never commit `key.properties` or `.jks` files to any repository

---

### 7. iOS/macOS Firebase config uses Android appId (MEDIUM)

**File:** `lib/firebase_options.dart` (lines 50-59)

iOS and macOS options reuse the Android `appId`:
```javascript
appId: '1:381626391822:android:63931f9d8e259076ac0b5f',
```

**Impact:** Firebase will reject iOS/macOS requests because the appId format is wrong (`ios:...` not `android:...`). iOS app won't initialize Firebase.

**Fix:** Register iOS app in Firebase Console → download `GoogleService-Info.plist` → regenerate with FlutterFire CLI.

---

### 8. Cloud Functions — Callable `rateLimit` doesn't verify auth (MEDIUM)

**File:** `functions/src/index.js` (line 164-168)

```javascript
const rateLimit = onCall({
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  ...
}, async (data, context) => {
  const action = data.action;
  const identifier = data.identifier;
  // NO check for context.auth!
```

**Impact:** The callable function enforces App Check but does NOT verify that the caller is authenticated. An unauthenticated user (with a valid debug App Check token) could call `rateLimit` to probe the rate-limiting system. The `identifier` is passed by the client — without `context.auth.uid` verification, the client could rate-limit a different user's identifier.

**Fix:** Add `if (!context.auth) throw new HttpsError('unauthenticated', '...');` at the top of the callable.

---

## 🟢 LOW FINDINGS / Already Secured

### 9. Firebase API Key visibility — ACCEPTABLE

**File:** `lib/firebase_options.dart`, `android/app/google-services.json`

Firebase API keys (`AIzaSy...gbdU`) are visible in source. This is **by design** — Firebase API keys are public identifiers, not secrets. Security is enforced by:
- App Check (Play Integrity in release)
- Firestore rules (server-side enforcement)
- Auth rules (server-side)

**Status:** ✅ No action needed.

---

### 10. Demo credentials — Secure pattern

**File:** `lib/main.dart`, `lib/data/repositories/auth_repository.dart`, `integration_test/test_credentials.dart`

Credentials are injected via `--dart-define`:
```bash
flutter run --dart-define=DEMO_ADMIN_EMAIL=... --dart-define=DEMO_ADMIN_PASSWORD=...
```

Test credentials use `String.fromEnvironment('TEST_ADMIN_EMAIL', defaultValue: 'admindemo@gmail.com')` — defaults are demo-only, overridable in CI.

**Status:** ✅ Secure pattern. The `FirebaseAuthException` error messages are generic to prevent email enumeration.

---

## 🔐 Security Strengths (Already Implemented)

### ✅ Rol immutability
Owner cannot escalate to admin — rules enforce:
```javascript
request.resource.data.rol == resource.data.rol
```

### ✅ App Check enforced on writes
All admin writes require `appCheckValida()` + `esAdmin()`.

### ✅ Pedidos state machine
Client can only update pedidos while `estado == 'pendiente'` — payment fields (`estado_pago`, `pago_verificado`, `payment_id`) are locked.

### ✅ Sorteo transaction safety
`SorteoRepository.participar()` uses a Firestore transaction to prevent duplicate entries, and admins are blocked from participating at the client level.

### ✅ FCM token cleanup
`FcmService.desuscribir()` deletes the token on logout; `onTokenRefresh` auto-updates.

### ✅ Password reset anti-enumeration
Login errors return generic `"Email o contraseña incorrectos"` — no user-found vs wrong-password distinction.

### ✅ Maps URL anti-phishing
`cuenta_screen.dart` validates URLs are HTTPS and host is in an allowlist before launching.

### ✅ Mercado Pago token isolation
`_accessToken` is `null` by default, only injectable via `--dart-define=MP_ACCESS_TOKEN`.

---

## 📋 Action Items (Prioritized)

| Priority | Task | Files Affected |
|----------|------|----------------|
| 🔴 **CRITICAL** | **Republish firestore.rules from `backup_20260902_0149/firestore.rules`** — current rules are a regression missing `pedidos`, sorteo participation, field validation, and whitelists | `firestore.rules`, Firebase Console |
| 🔴 **CRITICAL** | Fix `usuarios` CREATE rule — `hasAll()` requires `created_at`/`updated_at` but model writes `creado_en` | `firestore.rules` |
| 🟡 **HIGH** | Add `context.auth` check in Cloud Functions callable `rateLimit` | `functions/src/index.js` |
| 🟡 **HIGH** | Register iOS app in Firebase Console → fix `firebase_options.dart` iOS/macOS appId | `lib/firebase_options.dart` |
| 🟡 **HIGH** | Remove hardcoded App Check debug token from `firebase_backup_20260901/` and `backup_20260902_0149/` directories | backup files |
| 🟢 **MEDIUM** | Deploy Mercado Pago webhook Cloud Function (server-side total verification) | `functions/src/index.js` |
| 🟢 **MEDIUM** | Initialize git repo, ensure `.gitignore` covers all sensitive files | repo root |
| 🟢 **LOW** | Rotate demo account passwords | Firebase Auth Console |

---

## 🔄 Rule vs Model Field Alignment Matrix

| Collection | Field | Model writes | Current rule checks | Backup rule checks | Status |
|-----------|-------|-------------|---------------------|-------------------|--------|
| `usuarios` | `rol` | ✓ (write on create) | `request.resource.data.rol == resource.data.rol` (update) | Same | ✅ OK |
| `usuarios` | `tokens_balance` | ✓ | `>= resource.data.tokens_balance` | `>=` | ✅ OK |
| `usuarios` | `creado_en` | ✓ | ❌ Not in `hasAll()` | ❌ Not required | ⚠️ Mismatch |
| `usuarios` | `updated_at` | ❌ Not written | Required in `hasAll()` | N/A | 🔴 **DENIES create** |
| `pedidos` | `usuario_id` | ✓ | ❌ No match block | ✅ Checked | 🔴 **No rules** |
| `pedidos` | `estado` | ✓ | ❌ No match block | ✅ `== 'pendiente'` on create | 🔴 **No rules** |
| `sorteos` | `participantes` | ✓ (client append) | `esAdmin()` only | `esAdmin() \|\| client-append-safe` | 🔴 **Broken** |

---

## 📁 Backup Files Containing Sensitive Data

The following backup directories contain copies of `google-services.json` and `firebase_options.dart` with API keys. They also contain the correct historical rules. Review and clean up:

1. `backup_20260902_0149/` — Contains the **correct** hardened `firestore.rules` (USE THIS)
2. `firebase_backup_20260901/` — Contains older rules + hardcoded App Check debug token `e1860e7b-ce17-4b66-8da9-a14a1db098c7`

The `.gitignore` does NOT currently exclude these backup directories.

---

## 📄 Document History

- **2026-09-01:** Initial security hardening completed — rules published, credentials removed from code, App Check activated
- **2026-09-02:** Backup created at `backup_20260902_0149/` — contains correct rules
- **2026-09-03:** This audit — found regression in current `firestore.rules`
