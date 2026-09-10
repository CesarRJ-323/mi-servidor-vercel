import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/models/cart_item_model.dart';
export 'package:delivery_app_v2/models/cart_item_model.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void agregar(CartItem item) {
    final index = state.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      state[index].cantidad += item.cantidad;
    } else {
      state = [...state, item];
    }
  }

  void cambiarCantidad(String id, int nuevaCantidad) {
    final index = state.indexWhere((element) => element.id == id);
    if (index != -1 && nuevaCantidad > 0) {
      state[index].cantidad = nuevaCantidad;
    }
  }

  void eliminar(String id) {
    state = state.where((element) => element.id != id).toList();
  }

  void vaciar() {
    state = [];
  }

  int get totalItems => state.fold(0, (sum, item) => sum + item.cantidad);
  int get subtotal => state.fold(0, (sum, item) => sum + item.subtotal);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
