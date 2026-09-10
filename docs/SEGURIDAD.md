# Seguridad — Rapidiya Delivery App

## Auditoría completada: 2026-09-03

## Estado General: ⚠️ MODERADO (regresión de rules encontrada y corregida)

### Hallazgos PRINCIPALES

1. **[CRÍTICO] Reglas Firestore regresionaron** — El archivo `firestore.rules` actual
   NO contiene las reglas para `pedidos` ni la participación en sorteos.
   Las reglas correctas y endurecidas estaban en `backup_20260902_0149/firestore.rules`.
   **Fix:** `firestore.rules` fue reescrito con las reglas correctas (ver SECURITY_AUDIT.md).

2. **[CRÍTICO] Field name mismatch en usuarios CREATE** — La regla requería
   `created_at` y `updated_at` pero el modelo escribe `creado_en`. Esto
   **bloqueaba el registro de usuarios**. **Fix:** Regla corregida para usar
   `creado_en` y una whitelist de campos.

3. **[ALTO] Cloud Functions callable sin verificación de auth** — La función
   `rateLimit` no verifica `context.auth`. Aunque tiene App Check, un caller
   sin auth podría usarlo. **Fix:** Agregar `if (!context.auth) throw ...`
   en `functions/src/index.js`.

4. **[ALTO] iOS/macOS firebase_options usa Android appId** — Registroar app iOS
   en Firebase Console y regenerar `google-services.json` + `GoogleService-Info.plist`.

### Reglas endurecidas (publicadas y verificadas 31-ago, restauradas 3-sep)

- El rol en `usuarios/{uid}` es INMUTABLE vía update del dueño (solo `create` con rol 'cliente').
- `productos`, `promos`, `sorteos`, `descuentos`: escritura SOLO admin (`esAdmin()`).
- Sorteos: participación solo agrega 1 uid propio al array; ganadores/terminado solo admin.
- Pedidos: cliente crea (estado 'pendiente', total number>=0) y edita solo mientras pendiente;
  NUNCA toca `estado_pago`, `pago_verificado`, `payment_id` (para Mercado Pago).
- `firestore.rules` del repo = fuente de verdad. Copiar al Console tras cambios.

### Credenciales — reglas
- NADA de contraseñas hardcodeadas en código/tests/docs del repo.
- Tests: `integration_test/test_credentials.dart` centraliza las demo;
  los valores reales van por `--dart-define` (TEST_ADMIN_PASS, etc.).
- `asegurarCuentaDemo` / `asegurarCuentaConRol`: gated con `kDebugMode` —
  no existen en build release.
- Credenciales de producción (admin, Mercado Pago): gestor de claves de César.
- MP token: `--dart-define=MP_ACCESS_TOKEN=...` (nunca en el código).

### Pendientes de seguridad (orden sugerido)
1. ✅ [HECHO] Republish firestore.rules corregidas (incluye pedidos + sorteo participation).
2. [ ] Agregar `context.auth` check en Cloud Functions callable `rateLimit`.
3. [ ] Registrar app iOS en Firebase Console → arreglar firebase_options.dart.
4. [ ] Rotar password de admindemo/usuariodemo (Auth Console).
5. [ ] Deploy Mercado Pago webhook Cloud Function (server-side total verification).
6. [ ] Inicializar repo git + auditar primer push (make private).
7. [ ] Rotar debug App Check token en backups (ya en Console, pero en backups expuesto).

### Verificado 31-ago (REST, proyecto real)
- Cliente→rol admin: 403 ✅ | Cliente→productos: 403 ✅
- Cliente→descuentos: 403 ✅ | Admin→catálogo: OK ✅ | Lectura pública: OK ✅

### Security posture (post-fix)
Post-hardening risk assessment (small neighborhood zone, test phase): ~2-3%.
Highest FUTURE risk: fake "paid" orders when Mercado Pago activates without a webhook.
