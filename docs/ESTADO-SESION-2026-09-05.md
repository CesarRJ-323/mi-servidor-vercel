# SESION 5-sep-2026 — Estado Rapidiya (delivery_app_v2)

## Funcionando (verificado en emulador)
- Login con cuenta real: alegandraaraoz@gmail.com OK
- Login screen: flecha volver arriba-izquierda + formulario abajo (rediseñado)
- Panel admin: 4to ícono 🏪 (storefront) sale a la tienda SIN cerrar sesión
- Promos/sorteos/productos cargan de Firestore en tiempo real
- Mis compras recientes OK (índice compuesto pedidos: usuario_id+fecha_creacion creado)
- Categoría "Más" (id: mas) en chips del home
- Sistema tickets/tokens completo: sorteo exige y consume 1 ticket (tickets_balance),
  TicketService compra ticket x5 tokens, producto.tickets_reward acredita al comprar,
  Mi cuenta muestra saldos

## Causa raíz de TODOS los "Firebase se desconecta": App Check en modo "Aplicada"
- Cloud Firestore → Supervisión ✅ (hecho)
- Authentication → Supervisión ✅ (hecho)
- Firestore: leer reglas viejas deployadas daba PERMISSION_DENIED → publicadas nuevas

## Reglas firestore.rules (DEPLOYADAS 5-sep via CLI, cuenta soloesparabrawl75@gmail.com)
- Se sacó appCheckValida() de TODAS las escrituras admin (sorteos/promos/descuentos/
  productos/pedidos/historial) → solo exigen esAdmin() para poder desarrollar en emulador
- ⚠️ PARA PRODUCCIÓN: volver a agregar appCheckValida() a escrituras admin cuando
  la app esté en Play Store (Play Integrity genera el token bien)
- usuarios.create/update: tickets_balance en whitelist (sistema tickets)
- Firebase CLI quedó LOGUEADA (firebase deploy funciona directo)

## Pendientes producción
- App Check con Play Integrity en release + re-agregar appCheckValida() a rules
- Cloud Function webhook Mercado Pago (M6) antes de cobrar real
- M3/M5 (consolas Google) si aplican

## Archivos basura en raíz proyecto (Fase 3 limpieza pendiente)
fix_*.py, update_*.py, bisect_tmp.py removidos ya; quedan muchos fix_cart_*.py etc.

## APK
- Último app-debug.apk instalado en emulador con TODO lo de arriba
- flutter analyze lib: 0 errores
