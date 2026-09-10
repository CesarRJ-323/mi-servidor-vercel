class Producto {
  final String id;
  final String nombre;
  final num precioBase;
  final bool descuentoActivo;
  final num? porcentajeDescuento;
  final String urlImagen;
  final bool disponible;
  final int stock;
  final String descripcion;
  final String categoria;
  final int ticketsReward;
  final bool permiteTokens;
  final int precioTokens;

  Producto({
    required this.id,
    required this.nombre,
    required this.precioBase,
    this.descuentoActivo = false,
    this.porcentajeDescuento,
    required this.urlImagen,
    this.disponible = true,
    this.stock = 0,
    this.descripcion = '',
    this.categoria = '',
    this.ticketsReward = 0,
    this.permiteTokens = false,
    this.precioTokens = 0,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'] ?? '',
        nombre: json['nombre'] ?? '',
        precioBase: (json['precio_base'] ?? 0).toDouble(),
        descuentoActivo: json['descuento_activo'] ?? false,
        porcentajeDescuento: json['porcentaje_descuento']?.toDouble(),
        urlImagen: json['url_imagen'] ?? '',
        disponible: json['disponible'] ?? true,
        stock: json['stock'] ?? 0,
        descripcion: json['descripcion'] ?? '',
        categoria: json['categoria'] ?? '',
        ticketsReward: json['tickets_reward'] ?? 0,
        permiteTokens: json['permite_tokens'] ?? json['requiere_tokens'] ?? false,
        precioTokens: json['precio_tokens'] ?? 0,
      );

  /// Versión lowercase del nombre para búsqueda server-side prefix-based.
  /// Se guarda en Firestore como `nombre_lower` y se usa con queries
  /// `>=` y `<` para evitar escaneos completos de la colección.
  String get nombreLower => nombre.toLowerCase();

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'nombre_lower': nombreLower,
        'precio_base': precioBase,
        'descuento_activo': descuentoActivo,
        'porcentaje_descuento': porcentajeDescuento,
        'url_imagen': urlImagen,
        'disponible': disponible,
        'stock': stock,
        'descripcion': descripcion,
        'categoria': categoria,
        'tickets_reward': ticketsReward,
        'permite_tokens': permiteTokens,
        'requiere_tokens': permiteTokens, // Compatibilidad hacia atrás
        'precio_tokens': precioTokens,
      };

  // Precio con descuento aplicado (solo descuento PROPIO del producto)
  num get precioFinal {
    if (descuentoActivo && porcentajeDescuento != null) {
      return precioBase * (1 - porcentajeDescuento! / 100);
    }
    return precioBase;
  }

  /// Precio EN VIVO con prioridad:
  ///   1. Descuento propio del producto (descuento_activo en su doc)
  ///   2. Descuento por PRODUCTO de la coleccion descuentos (doc p_ + id)
  ///   3. Descuento por CATEGORÍA
  ///   4. Precio base
  num precioEnVivo(
    Map<String, int> descuentosCategoria, {
    Map<String, int> descuentosProducto = const {},
  }) {
    if (descuentoActivo && porcentajeDescuento != null) {
      return precioBase * (1 - porcentajeDescuento! / 100);
    }
    final pctProd = descuentosProducto[id];
    if (pctProd != null && pctProd > 0) {
      return precioBase * (1 - pctProd / 100);
    }
    // Category lookup with case-insensitive fallback:
    // Firestore keys are case-sensitive, but a product created with
    // categoria='Bebidas' won't match a discount key 'bebidas'.
    // Try exact match first, then lowercase normalization.
    var pctCat = descuentosCategoria[categoria];
    if ((pctCat == null || pctCat <= 0) && categoria.isNotEmpty) {
      pctCat = descuentosCategoria[categoria.toLowerCase()];
    }
    if (pctCat != null && pctCat > 0) {
      return precioBase * (1 - pctCat / 100);
    }
    return precioBase;
  }

  /// % de descuento efectivo para mostrar el badge.
  int? porcentajeEfectivo(
    Map<String, int> descuentosCategoria, {
    Map<String, int> descuentosProducto = const {},
  }) {
    if (descuentoActivo && porcentajeDescuento != null) {
      return porcentajeDescuento!.toInt();
    }
    final pctProd = descuentosProducto[id];
    if (pctProd != null && pctProd > 0) return pctProd;
    // Match case-insensitive: 'bebidas' vs 'Bebidas'
    var pctCat = descuentosCategoria[categoria];
    if ((pctCat == null || pctCat <= 0) && categoria.isNotEmpty) {
      pctCat = descuentosCategoria[categoria.toLowerCase()];
    }
    if (pctCat != null && pctCat > 0) return pctCat;
    return null;
  }
}
