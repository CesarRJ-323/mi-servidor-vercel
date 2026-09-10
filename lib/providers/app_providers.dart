import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';
import 'package:delivery_app_v2/data/repositories/usuario_repository.dart';
import 'package:delivery_app_v2/data/repositories/producto_repository.dart';
import 'package:delivery_app_v2/data/repositories/descuentos_repository.dart';
import 'package:delivery_app_v2/data/repositories/pedido_repository.dart';
import 'package:delivery_app_v2/data/repositories/sorteo_repository.dart';
import 'package:delivery_app_v2/data/repositories/promo_repository.dart';
import 'package:delivery_app_v2/services/rate_limiter_service.dart';
import 'package:delivery_app_v2/services/ticket_service.dart';
import 'package:delivery_app_v2/services/precio_service.dart';
import 'package:delivery_app_v2/models/usuario_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/models/producto_model.dart';
import 'package:delivery_app_v2/models/pedido_model.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';
import 'package:delivery_app_v2/models/promo_model.dart';
import 'package:delivery_app_v2/models/configuracion_pago_model.dart';

/// --- Instancias de repositorios (singletons vía provider) --- */
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) {
  return UsuarioRepository();
});

final productoRepositoryProvider = Provider<ProductoRepository>((ref) {
  return ProductoRepository();
});

final pedidoRepositoryProvider = Provider<PedidoRepository>((ref) {
  return PedidoRepository();
});

final sorteoRepositoryProvider = Provider<SorteoRepository>((ref) {
  return SorteoRepository();
});

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  return PromoRepository();
});

/// Servicio de rate limiting local (memoria) — previene spam de bots.
final rateLimiterProvider = Provider<RateLimiterService>((ref) {
  return RateLimiterService();
});

final descuentosRepositoryProvider = Provider<DescuentosRepository>((ref) {
  return DescuentosRepository();
});

/// Sorteos activos (visibles para el cliente en el home).
final sorteosActivosStreamProvider = StreamProvider<List<Sorteo>>((ref) {
  return ref.watch(sorteoRepositoryProvider).streamSorteosActivos();
});

/// Historial de sorteos terminados (últimos 7 días) con ganadores.
final sorteosHistorialStreamProvider = StreamProvider<List<Sorteo>>((ref) {
  return ref.watch(sorteoRepositoryProvider).streamHistorial(dias: 7);
});

/// Todas las promociones (panel admin).
final promosAdminStreamProvider = StreamProvider<List<Promo>>((ref) {
  return ref.watch(promoRepositoryProvider).streamTodasLasPromos();
});

/// Promociones combinadas (promos + descuentos) para la UI cliente.
final promosCombinadasStreamProvider = StreamProvider<List<Promo>>((ref) {
  return ref.watch(promoRepositoryProvider).streamPromocionesCombinadas();
});

/// --- Estado de autenticación (reemplaza el bool global _usuarioEsAdmin) --- */
final authStateProvider = StreamProvider<User?>((ref) =>
  ref.watch(authRepositoryProvider).authStateChanges);

/// ¿Hay sesión activa? (invitado = false)
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

/// Usuario actual como objeto de dominio (lee el doc `usuarios/{uid}`).
final usuarioActualProvider = FutureProvider<Usuario?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(usuarioRepositoryProvider).getUsuario(user.uid);
});

/// ¿Es admin? Deriva del documento del usuario. Seguro: viene de Firestore.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(usuarioActualProvider).valueOrNull?.esAdmin ?? false;
});

/// Descuentos por categoría activos: { 'cereales': 20, ... } en vivo.
/// Derivado del stream combinado para no mantener 2 listeners sobre
/// la misma colección `descuentos`.
final descuentosCategoriaProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(descuentosRepositoryProvider).streamCombinado()
      .map((c) => c.categoria);
});

/// Descuentos por producto activos: { productoId: % } en vivo.
/// Derivado del mismo stream combinado (1 listener, no 2).
final descuentosProductoProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(descuentosRepositoryProvider).streamCombinado()
      .map((c) => c.producto);
});

/// Stream UNIFICADO que escucha DESCUENTOS + PROMOS.
/// Es el provider que deben usar los screens para cálculo de precios
/// en vivo: antes solo escuchaba `descuentos` y las promos del 70%
/// en `promos` no afectaban el precio. AHORA: se unifican.
final preciosVivosProvider = StreamProvider<DescuentosCombinados>((ref) {
  return PrecioService().streamCombinadoUnificado();
});

/// Convenience: solo el mapa de categoría -> % (derivado del unificado).
/// Deriva del mismo PrecioService para que no abra un listener extra.
final preciosVivosCategoriaProvider =
    StreamProvider<Map<String, int>>((ref) {
  return PrecioService().streamCombinadoUnificado()
      .map((c) => c.categoria);
});

/// Convenience: solo el mapa de producto -> % (derivado del unificado).
final preciosVivosProductoProvider =
    StreamProvider<Map<String, int>>((ref) {
  return PrecioService().streamCombinadoUnificado()
      .map((c) => c.producto);
});

/// Streams de datos ---
final productosStreamProvider = StreamProvider<List<Producto>>((ref) {
  return ref.watch(productoRepositoryProvider).streamProductos();
});

final pedidosAdminStreamProvider = StreamProvider<List<Pedido>>((ref) {
  return ref.watch(pedidoRepositoryProvider).streamTodosLosPedidos();
});

final pedidosUsuarioStreamProvider = StreamProvider<List<Pedido>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(pedidoRepositoryProvider).streamPedidosDe(uid);
});

final configuracionPagoProvider = StateProvider<ConfiguracionPago?>((ref) => null);

/// Servicio de tickets (compra, uso, suma y consulta de balances)
final ticketServiceProvider = Provider<TicketService>((ref) => TicketService());

/// Balance actual de tickets (en tiempo real)
final ticketBalanceStreamProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('usuarios')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data()?['tickets_balance'] ?? 0);
});

/// Balance actual de tokens (en tiempo real)
final tokenBalanceStreamProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('usuarios')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data()?['tokens_balance'] ?? 0);
});