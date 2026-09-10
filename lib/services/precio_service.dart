import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

/// Resultado combinado de TODOS los descuentos/promos activos: un solo
/// snapshot contiene ambos maps (categoría y producto) para evitar
/// mantener listeners duplicados sobre distintas colecciones.
///
/// INCLUYE promociones de la colección `promos` (el cliente las publica
/// con aplicar_a = 'categoria:bebidas' | 'producto:abc123' | 'todos')
/// y descuentos de la colección `descuentos` (admin).
class DescuentosCombinados {
  final Map<String, int> categoria;
  final Map<String, int> producto;
  const DescuentosCombinados({
    required this.categoria,
    required this.producto,
  });
}

/// Servicio central de precios en vivo. Combina en UN stream todos los
/// descuentos/promos activos (descuentos admin + promos cliente) para
/// exponer un único mapa de porcentajes por categoría y por producto.
///
/// ANTES: el cliente solo escuchaba la colección `descuentos`, así que
/// las promociones creadas en `/promos` (aplicar_a: categoria:bebidas)
/// no afectaban el precio en vivo. AHORA: se unifican ambas fuentes.
class PrecioService {
  final FirebaseFirestore _db;
  PrecioService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Stream unificado que combina descuentos + promos.
  /// Si dos fuentes definen el mismo producto/categoría, GANA el mayor %.
  Stream<DescuentosCombinados> streamCombinadoUnificado() {
    final descSnap = _db.collection('descuentos').snapshots();
    final promoSnap = _db
        .collection('promos')
        .where('activa', isEqualTo: true)
        .snapshots();

    return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        DescuentosCombinados>(
      descSnap,
      promoSnap,
      (QuerySnapshot<Map<String, dynamic>> desc,
          QuerySnapshot<Map<String, dynamic>> promos) {
        final cat = <String, int>{};
        final prod = <String, int>{};

        // 1. Descuentos de la colección `descuentos`
        for (final d in desc.docs) {
          final data = d.data();
          final activo = data['activo'] ?? true;
          final pct = _parseInt(data['porcentaje']);
          if (!activo || pct <= 0) continue;

          final tipo = (data['tipo'] as String?)?.toLowerCase() ?? '';
          if (tipo == 'producto' || d.id.startsWith('p_')) {
            final pid = data['producto_id'] as String?;
            if (pid != null && pid.isNotEmpty) {
              prod.update(pid, (v) => pct > v ? pct : v, ifAbsent: () => pct);
            }
          } else {
            final categoria = (data['categoria'] ?? d.id).toString();
            // normalize a lowercase para match case-insensitive con productos
            cat.update(categoria.toLowerCase(),
                (v) => pct > v ? pct : v, ifAbsent: () => pct);
          }
        }

        // 2. Promos de la colección `promos` (activas, tipo porcentaje)
        for (final d in promos.docs) {
          final promo = Promo.fromJson({'id': d.id, ...d.data()});
          if (!promo.activa) continue;
          final pct =
              promo.tipo == 'porcentaje' ? promo.valor.toInt() : null;
          if (pct == null || pct <= 0) continue;

          if (promo.aplicarA.startsWith('categoria:')) {
            final categoria = promo.aplicarA.split(':')[1];
            if (categoria.isNotEmpty) {
              cat.update(categoria.toLowerCase(),
                  (v) => pct > v ? pct : v, ifAbsent: () => pct);
            }
          } else if (promo.aplicarA.startsWith('producto:')) {
            final parts = promo.aplicarA.split(':');
            final pid = parts.length > 1 ? parts[1] : '';
            if (pid.isNotEmpty) {
              prod.update(pid, (v) => pct > v ? pct : v, ifAbsent: () => pct);
            }
          }
          // aplicar_a == 'todos' → no afecta precios individuales
        }

        return DescuentosCombinados(categoria: cat, producto: prod);
      },
    );
  }

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse('$v') ?? 0;
}
