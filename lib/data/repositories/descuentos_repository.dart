import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/services/precio_service.dart';

/// Descuento por categoría (clase de alimento).
///
/// Colección `descuentos` — un doc por categoría con:
///   categoria: 'cereales'  (id de categoriasCatalogo)
///   porcentaje: 20
///   activo: true
///
/// Regla de prioridad al calcular el precio de un producto:
///   1. Si el PRODUCTO tiene descuento propio activo -> ese.
///   2. Si no, si su CATEGORÍA tiene descuento activo -> el de la categoría.
///   3. Si no, precio base.
class DescuentoCategoria {
  final String id;
  final String categoria; // id de la categoría (ej 'cereales')
  final int porcentaje;
  final bool activo;

  const DescuentoCategoria({
    required this.id,
    required this.categoria,
    required this.porcentaje,
    this.activo = true,
  });

  factory DescuentoCategoria.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const {};
    return DescuentoCategoria(
      id: d.id,
      categoria: (data['categoria'] ?? d.id).toString(),
      porcentaje: (data['porcentaje'] ?? 0) is int
          ? (data['porcentaje'] ?? 0) as int
          : int.tryParse('${data['porcentaje'] ?? 0}') ?? 0,
      activo: (data['activo'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        'porcentaje': porcentaje,
        'activo': activo,
      };
}

/// CRUD de descuentos por categoría (admin) + stream en vivo (cliente).
class DescuentosRepository {
  final FirebaseFirestore _db;
  DescuentosRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('descuentos');

  /// Stream único que emite el estado combinado de todos los descuentos
  /// activos DE LA COLECCIÓN `descuentos` (solo admin).
  /// Para el cliente, usar PrecioService.streamCombinadoUnificado() que
  /// también incluye promos de la colección `promos`.
  Stream<DescuentosCombinados> streamCombinado() {
    return _col.snapshots().map((snap) {
      final cat = <String, int>{};
      final prod = <String, int>{};
      for (final d in snap.docs) {
        final dc = DescuentoCategoria.fromDoc(d);
        if (!dc.activo || dc.porcentaje <= 0) continue;

        final tipo = (d.data()['tipo'] as String?)?.toLowerCase() ?? '';

        if (tipo == 'producto' || d.id.startsWith('p_')) {
          final pid = (d.data()['producto_id'] as String?);
          if (pid != null && pid.isNotEmpty) {
            prod[pid] = dc.porcentaje;
          }
        } else {
          // categoria normalizada a lowercase para match con productos
          cat[dc.categoria.toLowerCase()] = dc.porcentaje;
        }
      }
      return DescuentosCombinados(
        categoria: cat,
        producto: prod,
      );
    });
  }

  /// Legacy: cat -> pct (derivado del stream combinado). Se mantiene por compat.
  Stream<Map<String, int>> streamActivosPorCategoria() =>
      streamCombinado().map((c) => c.categoria);

  /// Legacy: prodId -> pct (derivado del stream combinado).
  Stream<Map<String, int>> streamActivosPorProducto() =>
      streamCombinado().map((c) => c.producto);

  /// Guarda (crea o actualiza) el descuento de una categoría.
  /// El doc usa el id de la categoría para que sea 1:1.
  /// Incluye field 'tipo: categoria' para que las reglas de Firestore
  /// y el streamCombinado puedan discriminar fácilmente.
  Future<void> guardar({
    required String categoria,
    required int porcentaje,
    required bool activo,
  }) async {
    // Siempre normalizamos a lowercase para que el key del mapa
    // coincida con categoria_model.categoriasCatalogo[id] (lowercase).
    final catLower = categoria.toLowerCase();
    await _col.doc(catLower).set({
      'tipo': 'categoria',
      'categoria': catLower,
      'porcentaje': porcentaje,
      'activo': activo,
      'actualizado_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eliminar(String categoria) => _col.doc(categoria).delete();

  // ============================================================
  //  DESCUENTOS POR PRODUCTO (individual)
  //  Misma colección, pero el doc usa el ID del producto con
  //  prefijo "p_" para no chocar con los ids de categoría:
  //  descuentos/p_<productoId>
  //    tipo: 'producto'
  //    producto_id: <id>
  //    producto_nombre: <nombre> (para mostrar en el panel)
  //    porcentaje: 15
  //    activo: true
  // ============================================================

  /// Guarda (o actualiza) el descuento de UN producto.
  Future<void> guardarDeProducto({
    required String productoId,
    required String productoNombre,
    required int porcentaje,
    required bool activo,
  }) async {
    await _col.doc('p_$productoId').set({
      'tipo': 'producto',
      'producto_id': productoId,
      'producto_nombre': productoNombre,
      'porcentaje': porcentaje,
      'activo': activo,
    }, SetOptions(merge: true));
  }

  /// Elimina el descuento de un producto.
  Future<void> eliminarDeProducto(String productoId) =>
      _col.doc('p_$productoId').delete();
}
