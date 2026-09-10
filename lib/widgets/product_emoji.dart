/// Mapeo producto -> emoji para el icono del carrito.
String emojiParaProducto(String nombre) {
  final lower = nombre.toLowerCase();
  if (lower.contains('avena')) return '🥣';
  if (lower.contains('granola')) return '🫐';
  if (lower.contains('café') || lower.contains('cafe')) return '☕';
  if (lower.contains('té') || lower.contains('te')) return '🍵';
  if (lower.contains('bebida')) return '🥤';
  if (lower.contains('fruta')) return '🍎';
  if (lower.contains('jugo') || lower.contains('naranja')) return '🧃';
  if (lower.contains('bizcocho') || lower.contains('pastel') || lower.contains('postre')) return '🍰';
  if (lower.contains('miel')) return '🍯';
  return '📦';
}
