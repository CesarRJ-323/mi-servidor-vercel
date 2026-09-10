import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

/// Promociones en la colección `promos`.
class PromoRepository {
  final FirebaseFirestore _db;

  PromoRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('promos');

  /// Promociones activas (lo usa el cliente en el home).
  Stream<List<Promo>> streamPromosActivas() {
    return _col
        .where('activa', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Promo.fromJson({'id': d.id, ...d.data()}))
            .toList()
          ..sort((a, b) =>
              (b.fechaCreacion ?? DateTime(0))
                  .compareTo(a.fechaCreacion ?? DateTime(0))));
  }

  /// Todas las promociones (lo usa el admin). Ordena en cliente para
  /// no depender de un índice compuesto en Firestore.
  Stream<List<Promo>> streamTodasLasPromos() {
    return _col.snapshots().map((snap) => snap.docs
        .map((d) => Promo.fromJson({'id': d.id, ...d.data()}))
        .toList()
      ..sort((a, b) =>
          (b.fechaCreacion ?? DateTime(0))
              .compareTo(a.fechaCreacion ?? DateTime(0))));
  }

  Future<void> crearPromo(Promo promo) async {
    await _col.add(promo.toJson());
  }

  Future<void> actualizarPromo(String id, Map<String, dynamic> datos) async {
    await _col.doc(id).update(datos);
  }

  Future<void> eliminarPromo(String id) async {
    await _col.doc(id).delete();
  }

  // -----------------------------------------------------------------
  // Stream combinado: promos + descuentos (antes en PromocionesRepository)
  // -----------------------------------------------------------------
  static const Map<String, String> _categoriaLabels = {
    'cereales': 'Cereales',
    'verduleria': 'Verdulería',
    'frutas': 'Frutas',
    'jugos': 'Jugos Naturales',
    'postres': 'Postres Artesanales',
    'bebidas': 'Bebidas',
  };

  /// Stream combinado: promos + descuentos.
  /// ROBUST: si la colección `descuentos` no existe en Firestore (prod),
  /// el stream NO falla — devuelve solo las promos reales y evita que
  /// el StreamBuilder caiga al fallback mock.
  Stream<List<Promo>> streamPromocionesCombinadas() {
    return _col
        .where('activa', isEqualTo: true)
        .snapshots()
        .asyncMap((promoSnap) async {
      final promos = promoSnap.docs
          .map((d) => Promo.fromJson({'id': d.id, ...d.data()}))
          .toList();

      // Descuentos por categoría — envuelto en try/catch para tolerar
      // colecciones inexistentes o queries sin índice (prod vs emulador).
      final descuentos = <Promo>[];
      try {
        final descSnap = await _db.collection('descuentos').get();
        for (final d in descSnap.docs) {
          final data = d.data();
          final activo = data['activo'] ?? true;
          final pct = (data['porcentaje'] ?? 0) is int
              ? (data['porcentaje'] ?? 0) as int
              : int.tryParse('${data['porcentaje'] ?? 0}') ?? 0;
          if (!activo || pct <= 0) continue;

          final id = d.id;
          final String nombre;
          final String aplicarA;

          if (id.startsWith('p_')) {
            final pid = id.substring(2);
            final prodNombre = data['producto_nombre'] as String? ?? 'Producto';
            nombre = '$pct% OFF $prodNombre';
            aplicarA = 'producto:$pid';
          } else {
            final label = _categoriaLabels[id] ?? id.toUpperCase();
            nombre = '$pct% OFF en $label';
            aplicarA = 'categoria:$id';
          }

          descuentos.add(Promo(
            id: 'desc_$id',
            nombre: nombre,
            descripcion: 'Descuento válido hoy',
            tipo: 'porcentaje',
            valor: pct.toDouble(),
            aplicarA: aplicarA,
            duracion: 'Hoy',
            activa: true,
            fechaCreacion: DateTime.now(),
          ));
        }
      } catch (e) {
        // No interrumpe el stream — si falla descuentos, seguimos con promos solas.
        // Evita el bug donde el StreamBuilder cae al mock fallback.
      }

      final todas = [...promos, ...descuentos];
      todas.sort((a, b) =>
          (b.fechaCreacion ?? DateTime(0))
              .compareTo(a.fechaCreacion ?? DateTime(0)));
      return todas;
    });
  }
}
