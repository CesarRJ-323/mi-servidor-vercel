import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/models/pedido_model.dart';
import 'package:delivery_app_v2/services/ticket_service.dart';

/// Pedidos en la colección `pedidos`.
class PedidoRepository {
  final FirebaseFirestore _db;

  PedidoRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('pedidos');

  /// Todos los pedidos (panel admin). Ordena server-side.
  /// NOTA: requiere índice compuesto en Firestore — al correr por
  /// primera vez, la consola mostrará un link para crearlo.
  Stream<List<Pedido>> streamTodosLosPedidos() {
    return _col
        .orderBy('fecha_creacion', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Pedido.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  /// Pedidos del usuario actual. Filtra y ordena server-side.
  Stream<List<Pedido>> streamPedidosDe(String uid) {
    return _col
        .where('usuario_id', isEqualTo: uid)
        .orderBy('fecha_creacion', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Pedido.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  Future<String> crearPedido(Pedido pedido) async {
    final docRef = await _col.add(pedido.toJson());

    // Award tickets based on products' ticketsReward.
    // OPTIMIZACIÓN: N GETs en paralelo (Future.wait) en vez de N GETs secuenciales.
    // Firebase Firestore no expone getAll() en cloud_firestore 6.x, así que usamos
    // Future.wait para disparar todos los gets al mismo tiempo — la latencia cae
    // de O(N*RTT) a O(1*RTT). También deduplicamos IDs repetidos.
    if (pedido.usuarioId.isNotEmpty && pedido.items.isNotEmpty) {
      final productIds = pedido.items
          .map((i) => i.productoId)
          .toSet() // deduplicar: mismo producto x2 = 1 read menos
          .where((id) => id.isNotEmpty)
          .toList();
      if (productIds.isEmpty) return docRef.id;

      final snapshots = await Future.wait(
        productIds.map((id) => _db.collection('productos').doc(id).get()),
      );

      // Build a lookup: productoId -> ticketsReward
      final rewardPorProducto = <String, int>{};
      for (var i = 0; i < snapshots.length; i++) {
        if (snapshots[i].exists) {
          final data = snapshots[i].data();
          if (data != null) {
            final rawReward = data['tickets_reward'] ?? 0;
            final reward = rawReward is int
                ? rawReward
                : int.tryParse('$rawReward') ?? 0;
            rewardPorProducto[productIds[i]] = reward;
          }
        }
      }

      int totalTickets = 0;
      for (final item in pedido.items) {
        final reward = rewardPorProducto[item.productoId] ?? 0;
        totalTickets += reward * item.cantidad;
      }
      if (totalTickets > 0) {
        await TicketService().sumarTickets(totalTickets);
      }
    }
    return docRef.id;
  }

  Future<void> actualizarEstado(String id, String estado) async {
    await _col.doc(id).update({
      'estado': estado,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina un pedido de Firestore (lo usa el admin para cancelados:
  /// los pedidos cancelados no aportan historial útil y ensucian el
  /// panel — al borrarlos desaparecen de "Total de pedidos" también).
  Future<void> eliminarPedido(String id) async {
    await _col.doc(id).delete();
  }
}