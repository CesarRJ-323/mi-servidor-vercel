# Análisis de Seguridad - Rapidiya Delivery App

## Resumen Ejecutivo

**Estado General:** ⚠️ **MODERADO** - La app funciona correctamente pero tiene vulnerabilidades de seguridad en código, configuración y manejo de credenciales.

---

## 🔍 CRÍTICO: Credenciales Hardcodeadas en Código Fuente

**Archivo:** `lib/main.dart` (líneas 44-45, 112-113)

```dart
email: 'admindemo@gmail.com',
password: 'Admin1234',
// Fallback: clientedemo@gmail.com / Cliente1234
```

**Riesgo:** 🔴 **CRÍTICO**  
Las credenciales de demo están hardcodeadas en el código fuente. Aunque están dentro de un `kDebugMode` check, este código se incluye en el APK debug y podría extraerse.

**Recomendación:**
- Mover credenciales demo a variables de entorno o archivo `.env` (excluido de VCS)
- Eliminar el fallback de `clientedemo@gmail.com`
- Usar `--dart-define` para pasar credenciales en build time

---

## 🔍 ALTO: App Check Enforcement Mode Activo

**Estado:** ✅ Token debug registrado (`e1860e7b-ce17-4b66-8da9-a14a1db098c7`)  
**Problema:** App Check está en **enforcement mode**, lo que bloquea peticiones REST a Firestore/Auth sin token de App Check válido.

**Impacto:** Las llamadas desde scripts externos (cloud functions, tests CI) fallan con "Firebase App Check token is invalid."

**Recomendación:**
- Usar `firebase appcheck` para gestionar modos de enforcement
- En production: usar Play Integrity provider (ya configurado)
- En CI/testing: registrar debug tokens con límite de tiempo

---

## 🔍 ALTO: API Keys Visibles en firebase_options.dart

**Archivo:** `lib/firebase_options.dart`  
Las API keys de Firebase están parcialmente visibles en el código fuente.

**Riesgo:** 🔴 **ALTO**  
Las API keys públicas pueden ser usadas por terceros para hacer llamadas autenticadas (aunque App Check las bloquearía).

**Recomendación:**
- Las API keys son necesarias en cliente (no hay alternativa)
- Depender de App Check + Firestore rules para seguridad real

---

## 🔍 MEDIO: Credenciales de Keystore en key.properties

**Archivo:** `key.properties` (en raíz del proyecto)

```
storeFile=C:/Users/lia/keystore/rapidiya-release-key.jks
storePassword=kTeWwwsmYIm4WFkbLv63ssEu
keyAlias=rapidiya
keyPassword=kTeWwwsmYIm4WFkbLv63ssEu
```

**Riesgo:** 🟡 **MEDIO**  
Las credenciales del keystore están hardcodeadas. Si este archivo se sube a un repositorio, un atacante podría firmar APKs maliciosos como actualizaciones legítimas.

**Recomendación:**
- Mover `key.properties` a variables de entorno CI/CD
- Agregar `key.properties` a `.gitignore` (NO está en VCS actualmente ✓)
- Considerar Google Play App Signing en lugar de keystore local

---

## 🔍 MEDIO: Logs de Debug Exponen Información de Usuario

**Archivo:** `lib/main.dart` (líneas 47, 115)

```dart
debugPrint('[Debug] Auto-login exitoso: ${cred.user?.email} (uid=${cred.user?.uid})');
```

**Riesgo:** 🟡 **MEDIO**  
Los logs debug incluyen email y UID del usuario. Si un atacante tiene acceso al dispositivo o a logcat, podría obtener información sensible.

**Recomendación:**
- Remover logs con información sensible antes de producción
- Usar un nivel de logging configurable

---

## 🔍 BAJO: Sin Repositorio Git

**Problema:** El proyecto NO tiene repositorio git inicializado.

**Riesgo:** 🟢 **BAJO**  
Sin control de versiones, es difícil rastrear cambios, auditar modificaciones o revertir errores. Los backups son manuales y poco confiables.

**Recomendación:**
- Inicializar git: `git init && git add . && git commit -m "initial"`
- Agregar `.gitignore` para excluir: `key.properties`, `.env`, `build/`, `*.apk`, `*.aab`, `*.jks`
- Considerar subir a GitHub/GitLab con protección de rama

---

## 🔍 BAJO: App Check Debug Token Expuesto

**Token:** `e1860e7b-ce17-4b66-8da9-a14a1db098c7`  
Este token está visible en los logs de la app (`DebugAppCheckProvider: Enter this debug secret into the allow list`).

**Riesgo:** 🟢 **BAJO**  
El token debug permite que App Check acepte peticiones del emulador. Si cae en manos de terceros, podrían usarlo para acceder con App Check válido.

**Recomendación:**
- Rotar el token debug si se comparte
- No compartir el token en código público
- Configurar en Firebase Console > App Check > Debug tokens

---

## ✅ Aspectos Positivos (Seguridad Bien Implementada)

1. **Firestore Rules robustas** — Usuarios solo pueden leer/escribir su propio documento, roles inmutables, validación de descuentos (0-100%)
2. **App Check configurado** — Debug provider en desarrollo, Play Integrity en release
3. **Multiplexado de pagos** — Pedidos bloquean edición de campos de pago (`estado_pago`, `pago_verificado`, `payment_id`)
4. **Admin verification** — `esAdmin()` verifica rol desde Firestore, no del cliente
5. **Whitelist de campos** — Users solo pueden editar campos específicos (nombre, teléfono, dirección...)
6. **Token balance protegido** — `tokens_balance` es inmutable vía cliente
7. **Pedido state validation** — Solo editable mientras esté `pendiente`

---

## 📋 Checklist de Remedios

| Prioridad | Tarea | Estado |
|-----------|-------|--------|
| CRÍTICO | Eliminar credenciales hardcodeadas de main.dart | ❌ Pendiente |
| ALTO | Migrar key.properties a env vars / secret manager | ❌ Pendiente |
| ALTO | Rotar API key de Firebase (si se expuso) | ❌ Pendiente |
| MEDIO | Remover debugPrint con datos sensibles | ❌ Pendiente |
| MEDIO | Configurar .gitignore apropiado | ❌ Pendiente |
| BAJO | Inicializar repositorio git | ❌ Pendiente |
| INFORME | Hacer commit de firestore.rules actualizado | ❌ Pendiente |

---

## 📁 Backup de Estado Creado

**Carpeta:** `backup_20260902_0149/`  
Contiene:
- `lib/` (todos los archivos Dart)
- `android/` (config completa)
- `firebase_options.dart`, `firestore.rules`, `.firebaserc`, `google-services.json`
- `integration_test/`
- `scripts/`

**También existe:** `firebase_backup_20260901/` (backup anterior)
