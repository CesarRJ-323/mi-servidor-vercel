# Tareas — delivery_app_v2 Mejoras

## Fase 1 — Parches Críticos de Seguridad
- [x] 1.1 Eliminar bypass de App Check en firestore.rules
- [x] 1.2 Restringir create/update de productos a esAdmin()
- [x] 1.3 Eliminar N+1 query en realizarSorteo()
- [x] 1.4 Limpiar credenciales del .env

## Fase 2 — Optimización de Firestore
- [x] 2.1 Filtro server-side en streamHistorial()
- [x] 2.2 Filtro server-side en purgarAntiguos()
- [x] 2.3 orderBy server-side en pedidos
- [x] 2.4 Debounce + mejora de búsqueda de productos (PREFIX-BASED SERVER-SIDE)
- [x] 2.5 Registrar DescuentosRepository como provider

## Fase 3 — Limpieza de Código Zombi
- [x] 3.1 Eliminar credenciales hardcodeadas de scripts/get_token.py
- [x] 3.2 Eliminar directorio _zombis/ (no existía)
- [x] 3.3 Eliminar archivos de sesión/desarrollo (no existían)
- [x] 3.4 Consolidar PromocionesRepository → PromoRepository
- [x] 3.5 Eliminar home_screen_optimizado.dart (no existía)

## Fase 4 — Refactor Arquitectónico
- [x] 4.1 Descomponer God Widget home_screen.dart (1066 → ~60 líneas)
- [x] 4.2 Migrar a CustomScrollView + Slivers
- [x] 4.3 Extraer widget EmptyStateCard reutilizable

## Verificación
- [x] flutter analyze — 0 errors, 1 info (pre-existing)
- [x] flutter build apk --release — exitoso (55.4MB)
