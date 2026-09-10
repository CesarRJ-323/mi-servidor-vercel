import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import 'package:delivery_app_v2/services/precio_service.dart';
import 'package:delivery_app_v2/models/producto_model.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';

/// ViewModel consolidado para el HomeScreen.
/// Combina múltiples streams de Firestore en UNO solo para minimizar:
/// - Listeners activos simultáneos
/// - Rebuilds del widget
/// - Consumo de memoria/CPU en dispositivos móviles
final homeDataConsolidadoProvider = StreamProvider.autoDispose<HomeData>((ref) {
  final productoRepo = ref.watch(productoRepositoryProvider);

  // Streams individuales con límites para evitar sobrecarga
  final productos$ = productoRepo.streamProductos(limite: 50);
  // UN SOLO listener que escucha DESCUENTOS + PROMOS (precio unificado).
  // ANTES: escuchaba solo `descuentos` y no veía las promos del 70%.
  final descuentos$ = PrecioService().streamCombinadoUnificado();

  // Combinar streams con Rx.combineLatest2
  return Rx.combineLatest2<List<Producto>, DescuentosCombinados, HomeData>(
    productos$,
    descuentos$,
    (productos, desc) => HomeData(
      productos: productos,
      descuentosCategoria: desc.categoria,
      descuentosProducto: desc.producto,
    ),
  );
});

/// Modelo de datos unificado para los datos del home.
/// Incluye productos pre-calculados con descuentos aplicados.
class HomeData {
  final List<Producto> productos;
  final Map<String, int> descuentosCategoria;
  final Map<String, int> descuentosProducto;

  const HomeData({
    required this.productos,
    required this.descuentosCategoria,
    required this.descuentosProducto,
  });

  /// Lista de productos con precios calculados en vivo.
  /// Se calcula una sola vez por snapshot para evitar recálculos repetidos.
  List<({Producto producto, int precioFinal, int? porcentajeDescuento})>
      get productosConPrecio {
    return productos.map((p) {
      final pct = p.porcentajeEfectivo(
        descuentosCategoria,
        descuentosProducto: descuentosProducto,
      );
      final precio = p.precioEnVivo(
        descuentosCategoria,
        descuentosProducto: descuentosProducto,
      );
      return (
        producto: p,
        precioFinal: precio.toInt(),
        porcentajeDescuento: pct,
      );
    }).toList();
  }

  /// Precio final para un producto específico (cálculo único por snapshot).
  ({int precioFinal, int? porcentajeDescuento}) precioFinalPara(Producto p) {
    final pct = p.porcentajeEfectivo(
      descuentosCategoria,
      descuentosProducto: descuentosProducto,
    );
    final precio = p.precioEnVivo(
      descuentosCategoria,
      descuentosProducto: descuentosProducto,
    );
    return (precioFinal: precio.toInt(), porcentajeDescuento: pct);
  }

  /// Debug helper - loggear estado del home data
  void debugLog() {
    if (kDebugMode) {
      print('[HomeData] Productos: ${productos.length} | '
          'DescCat: ${descuentosCategoria.length} | '
          'DescProd: ${descuentosProducto.length}');
    }
  }
}
