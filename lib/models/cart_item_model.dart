// Modelo del carrito - definición única
class CartItem {
  final String id;
  final String nombre;
  final int precio;
  int cantidad;
  final String icono;
  final bool requiereTokens;

  CartItem({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.icono,
    this.requiereTokens = false,
  });

  // Getter faltante
  int get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'cantidad': cantidad,
        'icono': icono,
        'requiere_tokens': requiereTokens,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] ?? '',
        nombre: json['nombre'] ?? '',
        precio: json['precio'] ?? 0,
        cantidad: json['cantidad'] ?? 1,
        icono: json['icono'] ?? '📦',
        requiereTokens: json['requiere_tokens'] ?? false,
      );
}
