import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/models/producto_model.dart';

/// Catálogo de productos en la colección `productos`.
class ProductoRepository {
  final FirebaseFirestore _db;

  ProductoRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('productos');

  /// Catálogo en vivo (home/category se actualizan solos).
  /// [limite] opcional para paginación/paginado — evita traer todos los
  /// productos a la vez en dispositivos móviles (reduce memoria + latencia).
  Stream<List<Producto>> streamProductos({int? limite}) {
    Query<Map<String, dynamic>> query = _col.orderBy('nombre');
    if (limite != null && limite > 0) query = query.limit(limite);
    return query.snapshots().map((snap) => snap.docs
        .map((d) => Producto.fromJson({'id': d.id, ...d.data()}))
        .toList());
  }

  /// Productos de una categoría (filtra por campo suelto, sin índice).
  Stream<List<Producto>> streamProductosDeCategoria(String categoria) {
    return _col
        .where('categoria', isEqualTo: categoria)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Producto.fromJson({'id': d.id, ...d.data()}))
            .toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre)));
  }

  /// Búsqueda por nombre (prefix-based, server-side).
  /// Usa el campo `nombre_lower` con queries `>=`/`<` para escanear solo
  /// los docs que empiezan con el prefijo — evita descargar toda la colección.
  /// El debounce de 300ms se aplica en el widget de búsqueda (SearchScreen).
  Stream<List<Producto>> streamBuscar(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Stream.empty();
    // Rango de strings que empiezan con q: [q, q + 'z' + 1)
    // Usamos un carácter que ordene después de cualquier string que empiece con q.
    final end = '$q\uffff';
    return _col
        .where('nombre_lower', isGreaterThanOrEqualTo: q)
        .where('nombre_lower', isLessThan: end)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Producto.fromJson({'id': d.id, ...d.data()}))
            .toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre)));
  }

  Future<List<Producto>> getProductos() async {
    final snap = await _col.orderBy('nombre').get();
    return snap.docs
        .map((d) => Producto.fromJson({'id': d.id, ...d.data()}))
        .toList();
  }

  // --- Operaciones de admin ---
  Future<void> crearProducto(Producto producto) async {
    await _col.add(producto.toJson());
  }

  Future<void> actualizarProducto(String id, Map<String, dynamic> datos) async {
    // Usa SetOptions(merge: true) para escrituras atómicas y evitar que
    // el stream rebote con valores stale cuando hay writes rápidos (ej: toggle).
    await _col.doc(id).set(datos, SetOptions(merge: true));
  }

  Future<void> eliminarProducto(String id) async {
    await _col.doc(id).delete();
  }
}
