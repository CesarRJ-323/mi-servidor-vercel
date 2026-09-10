class PedidoItem {
  final String productoId;
  final String nombreProducto;
  final int cantidad;
  final double precioUnitario;
  final String? promoAplicada;

  PedidoItem({
    required this.productoId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    this.promoAplicada,
  });

  factory PedidoItem.fromJson(Map<String, dynamic> json) => PedidoItem(
        productoId: json['producto_id'] ?? '',
        nombreProducto: json['nombre_producto'] ?? '',
        cantidad: json['cantidad'] ?? 1,
        precioUnitario: (json['precio_unitario'] ?? 0).toDouble(),
        promoAplicada: json['promo_aplicada'],
      );

  Map<String, dynamic> toJson() => {
        'producto_id': productoId,
        'nombre_producto': nombreProducto,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'promo_aplicada': promoAplicada,
      };
}

enum EstadoPedido { pendiente, confirmado, enCamino, entregado, cancelado }

class Pedido {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String usuarioTelefono;
  final String usuarioWhatsapp;
  final String mapsUrl;
  final String descripcionCasa;
  final List<PedidoItem> items;
  final double subtotal;
  final double descuentoAplicado;
  final int tokensUtilizados;
  final double total;
  final String direccionEnvio;
  final EstadoPedido estado;
  final String? metodoPagoId;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Pedido({
    required this.id,
    required this.usuarioId,
    this.usuarioNombre = '',
    this.usuarioTelefono = '',
    this.usuarioWhatsapp = '',
    this.mapsUrl = '',
    this.descripcionCasa = '',
    required this.items,
    required this.subtotal,
    this.descuentoAplicado = 0,
    this.tokensUtilizados = 0,
    required this.total,
    required this.direccionEnvio,
    this.estado = EstadoPedido.pendiente,
    this.metodoPagoId,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) => Pedido(
        id: json['id'] ?? '',
        usuarioId: json['usuario_id'] ?? '',
        usuarioNombre: json['usuario_nombre'] ?? '',
        usuarioTelefono: json['usuario_telefono'] ?? '',
        usuarioWhatsapp: json['usuario_whatsapp'] ?? '',
        mapsUrl: json['maps_url'] ?? '',
        descripcionCasa: json['descripcion_casa'] ?? '',
        items: (json['items'] as List<dynamic>?)?.map((item) => PedidoItem.fromJson(item)).toList() ?? [],
        subtotal: (json['subtotal'] ?? 0).toDouble(),
        descuentoAplicado: (json['descuento_aplicado'] ?? 0).toDouble(),
        tokensUtilizados: json['tokens_utilizados'] ?? 0,
        total: (json['total'] ?? 0).toDouble(),
        direccionEnvio: json['direccion_envio'] ?? '',
        estado: _parseEstado(json['estado']?.toString()),
        metodoPagoId: json['metodo_pago_id']?.toString(),
        fechaCreacion: _parseFecha(json['fecha_creacion']) ?? DateTime.now(),
        fechaActualizacion: _parseFecha(json['fecha_actualizacion']),
      );

  /// Acepta Timestamp de Firestore, ISO String o null sin crashear.
  static DateTime? _parseFecha(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    // Timestamp de cloud_firestore (evita import ciclico: duck-typing)
    try {
      final ms = (v as dynamic).millisecondsSinceEpoch;
      if (ms is int) return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    return DateTime.tryParse(v.toString());
  }

  static EstadoPedido _parseEstado(String? estado) {
    switch (estado) {
      case 'pendiente': return EstadoPedido.pendiente;
      case 'confirmado': return EstadoPedido.confirmado;
      case 'en_camino': return EstadoPedido.enCamino;
      case 'entregado': return EstadoPedido.entregado;
      case 'cancelado': return EstadoPedido.cancelado;
      default: return EstadoPedido.pendiente;
    }
  }

  Map<String, dynamic> toJson() => {
        'usuario_id': usuarioId,
        'usuario_nombre': usuarioNombre,
        'usuario_telefono': usuarioTelefono,
        'usuario_whatsapp': usuarioWhatsapp,
        'maps_url': mapsUrl,
        'descripcion_casa': descripcionCasa,
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'descuento_aplicado': descuentoAplicado,
        'tokens_utilizados': tokensUtilizados,
        'total': total,
        'direccion_envio': direccionEnvio,
        'estado': estado.toString().split('.').last,
        'metodo_pago_id': metodoPagoId,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      };
}
