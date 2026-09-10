import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/models/producto_model.dart';

import 'package:delivery_app_v2/providers/cart_provider.dart';
import 'package:delivery_app_v2/widgets/product_card.dart';
import 'package:delivery_app_v2/widgets/product_emoji.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;

  // Nombre legible por categoría (id -> título). El doc de Firestore puede
  // no traer el nombre, así que lo mapeamos.
  static const Map<String, String> _nombres = {
    'cereales': 'Cereales',
    'bebidas': 'Bebidas',
    'frutas': 'Frutas / Verduras',
    'jugos': 'Jugos / Infusiones',
    'postres': 'Postres / Meriendas',
    'matesAccesorios': 'Mates y Accesorios',
    'mas': 'Más',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombreCat = _nombres[categoryId] ?? 'Productos';
    final repo = ref.watch(productoRepositoryProvider);

    return Scaffold(
      body: Column(
        children: [
          // Header con back button
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
            ),
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
                Text(
                  nombreCat,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Carrito con badge
                Consumer(
                  builder: (context, ref, _) {
                    final total = ref.watch(cartProvider)
                        .fold(0, (sum, item) => sum + item.cantidad);
                    return Stack(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/cart'),
                          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                        ),
                        if (total > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$total',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Lista de productos (Firestore)
          Expanded(
            child: StreamBuilder<List<Producto>>(
              stream: repo.streamProductosDeCategoria(categoryId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudieron cargar los productos.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final productos = snap.data!;
                if (productos.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos disponibles',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final producto = productos[index];
                    final descuentosCat =
                        ref.watch(preciosVivosCategoriaProvider).valueOrNull ??
                            const {};
                    final descuentosProd =
                        ref.watch(preciosVivosProductoProvider).valueOrNull ??
                            const {};
                    return ProductCard(
                      producto: producto,
                      descuentosCategoria: descuentosCat,
                      onAgregar: () {
                        // Invitado -> pedir login antes de comprar.
                        if (!ref.read(isLoggedInProvider)) {
                          context.push('/login');
                          return;
                        }
                        ref.read(cartProvider.notifier).agregar(
                          CartItem(
                            id: producto.id,
                            nombre: producto.nombre,
                            precio: producto.precioEnVivo(
                              descuentosCat,
                              descuentosProducto: descuentosProd,
                            ).toInt(),
                            cantidad: 1,
                            icono: emojiParaProducto(producto.nombre),
                            requiereTokens: producto.requiereTokens,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${producto.nombre} agregado al carrito 🛒'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Footer WhatsApp
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: '+5492494690672'));
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    '📋 Número copiado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.green[600],
                  duration: const Duration(seconds: 2),
                  margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💬', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Contáctanos por WhatsApp',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
