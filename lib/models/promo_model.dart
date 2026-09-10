class Promo {
  final String id;
  final String nombre;
  final String descripcion;
  final String tipo; // 'porcentaje' | '2x1' | 'monto_fijo'
  final num valor;
  final String aplicarA; // 'todos' | 'categoria:xxx' | 'producto:xxx'
  final String duracion;
  final bool activa;
  final DateTime? fechaCreacion;

  Promo({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.tipo = 'porcentaje',
    this.valor = 0,
    this.aplicarA = 'todos',
    this.duracion = '',
    this.activa = true,
    this.fechaCreacion,
  });

  factory Promo.fromJson(Map<String, dynamic> json) => Promo(
        id: json['id'] ?? '',
        nombre: json['nombre'] ?? '',
        descripcion: json['descripcion'] ?? '',
        tipo: json['tipo'] ?? 'porcentaje',
        valor: (json['valor'] ?? 0).toDouble(),
        aplicarA: json['aplicar_a'] ?? 'todos',
        duracion: json['duracion'] ?? '',
        activa: json['activa'] ?? true,
        fechaCreacion: json['fecha_creacion'] != null
            ? DateTime.tryParse(json['fecha_creacion'])
            : null,
      );

  /// Extrae la categoría ID de aplicarA (ej: 'categoria:cereales' → 'cereales').
  /// Útil para el cliente al filtrar promos por categoría.
  String? get categoriaId {
    if (aplicarA.startsWith('categoria:')) {
      return aplicarA.split(':')[1];
    }
    return null;
  }

  /// Extrae el producto ID de aplicarA (ej: 'producto:abc123' → 'abc123').
  String? get productoId {
    if (aplicarA.startsWith('producto:')) {
      return aplicarA.split(':')[1];
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'tipo': tipo,
        'valor': valor,
        'aplicar_a': aplicarA,
        'duracion': duracion,
        'activa': activa,
        'fecha_creacion': fechaCreacion?.toIso8601String(),
      };
}
