import 'dart:async';

import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/cart_provider.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/producto_model.dart';

/// Pantalla de búsqueda de productos (lupa). Filtra en tiempo real por nombre
/// leyendo de Firestore. Toca un producto para agregarlo al carrito.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  // Debounce: evita disparar el query en cada keystroke.
  // 300ms de inactividad en la escritura antes de buscar.
  Timer? _debounce;
  final _queryProvider = StateProvider<String>((ref) => '');

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_queryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escucha el query debounced (actualizado 300ms después de dejar de escribir)
    final debouncedQuery = ref.watch(_queryProvider);
    final controllerQuery = _controller.text;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Buscar productos'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
      ),
      body: Column(
        children: [
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controllerQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _controller.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Resultados
          Expanded(
            child: StreamBuilder<List<Producto>>(
              stream: ref
                  .watch(productoRepositoryProvider)
                  .streamBuscar(debouncedQuery),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los productos.'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final productos = snap.data!;
                if (debouncedQuery.isEmpty) {
                  return const Center(
                    child: Text(
                      'Escribí para buscar productos.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                if (productos.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron productos.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final p = productos[index];
                    return ProductoBusquedaCard(producto: p);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductoBusquedaCard extends ConsumerWidget {
  final Producto producto;

  const ProductoBusquedaCard({super.key, required this.producto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descuentosCategoria = ref.watch(preciosVivosCategoriaProvider).value ?? {};
    final descuentosProducto = ref.watch(preciosVivosProductoProvider).value ?? {};
    final precioEnVivo = producto.precioEnVivo(descuentosCategoria, descuentosProducto: descuentosProducto);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: _buildImagen(producto),
        title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          producto.descripcion.isNotEmpty ? producto.descripcion : 'Sin descripción',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (producto.permiteTokens) ...[
              Text(
                '\$${precioEnVivo.toInt()} | ${producto.precioTokens} 🪙',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ] else ...[
              Text(
                '\$${precioEnVivo.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                // Invitado -> pedir login antes de comprar.
                if (!ref.read(isLoggedInProvider)) {
                  context.push('/login');
                  return;
                }

                final pct = producto.porcentajeEfectivo(descuentosCategoria, descuentosProducto: descuentosProducto);
                String? promoName;
                if (pct != null && pct > 0) {
                  promoName = pct == 50 ? '2x1 o 50% OFF' : '$pct% OFF';
                }

                void agregarAlCarrito(bool conTokens) {
                  ref.read(cartProvider.notifier).agregar(
                    CartItem(
                      id: producto.id,
                      nombre: producto.nombre,
                      precio: conTokens ? producto.precioTokens : precioEnVivo.toInt(),
                      cantidad: 1,
                      icono: _emoji(producto.nombre),
                      requiereTokens: conTokens,
                      promoAplicada: promoName,
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
                }

                if (producto.permiteTokens) {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('¿Cómo querés pagar este producto?',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.attach_money, color: Colors.green),
                            title: const Text('Pagar con Plata'),
                            subtitle: Text('\$${precioEnVivo.toInt()}'),
                            onTap: () {
                              Navigator.pop(ctx);
                              agregarAlCarrito(false);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.monetization_on, color: Colors.amber),
                            title: const Text('Pagar con Tokens'),
                            subtitle: Text('${producto.precioTokens} 🪙'),
                            onTap: () {
                              Navigator.pop(ctx);
                              agregarAlCarrito(true);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  agregarAlCarrito(false);
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagen(Producto p) {
    if (p.urlImagen.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          p.urlImagen,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          cacheWidth: 100, // decodifica a 2x el tamaño mostrado (ahorra RAM)
          errorBuilder: (_, _, _) => _placeholder(p),
        ),
      );
    }
    return _placeholder(p);
  }

  Widget _placeholder(Producto p) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(_emoji(p.nombre), style: const TextStyle(fontSize: 26)),
    );
  }
}

String _emoji(String nombre) {
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
