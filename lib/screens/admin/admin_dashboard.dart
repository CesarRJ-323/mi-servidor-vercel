import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/pedido_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pedidos en vivo desde Firebase (todos los usuarios).
    final pedidosAsync = ref.watch(pedidosAdminStreamProvider);

    // Estados que cuentan como "en marcha" (no finalizados).
    const enMarcha = {
      EstadoPedido.pendiente,
      EstadoPedido.confirmado,
      EstadoPedido.enCamino,
    };

    final todos = pedidosAsync.value ?? [];
    final pedidosActivos =
        todos.where((p) => enMarcha.contains(p.estado)).toList();
    final recientes = todos.take(5).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // App Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF2A0800),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rapidiya',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.push('/admin/producto'),
                      icon: const Icon(Icons.add_box, color: Colors.white),
                      tooltip: 'Agregar producto',
                    ),
                    IconButton(
                      onPressed: () => context.push('/admin/sorteo'),
                      icon: const Icon(Icons.card_giftcard, color: Colors.white),
                      tooltip: 'Publicar sorteo',
                    ),
                    IconButton(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).cerrarSesion();
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Cerrar sesión',
                    ),
                    IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.storefront, color: Colors.white),
                      tooltip: 'Salir del panel (ir a la tienda)',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A0800),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard(
                          '${pedidosActivos.length}',
                          'Pedidos en marcha',
                        ),
                        _buildStatCard('${todos.length}', 'Total de pedidos'),
                        _buildStatCard(
                          '${pedidosActivos.where((p) => p.estado == EstadoPedido.enCamino).length}',
                          'En camino',
                        ),
                        _buildStatCard(
                          '${todos.where((p) => p.estado == EstadoPedido.entregado).length}',
                          'Entregados',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Acceso: descuentos por categoría
                    GestureDetector(
                      onTap: () => context.push('/admin/descuentos'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.percent_rounded,
                                color: AppColors.primary),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Descuentos por categoría',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    // Pedidos recientes (en vivo)
                    const Text(
                      'Pedidos recientes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pedidosAsync.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (recientes.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No hay pedidos registrados.'),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          children: recientes
                              .map((p) => _buildPedidoRow(p))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Navigation
          BottomAppBar(
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bottomNavItem(Icons.home, 'Inicio', 0, context),
                _bottomNavItem(Icons.receipt_long, 'Pedidos', 1, context),
                _bottomNavItem(Icons.inventory_2, 'Productos', 2, context),
                _bottomNavItem(Icons.local_offer, 'Promos', 3, context),
                _bottomNavItem(Icons.card_giftcard, 'Sorteos', 4, context),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0891B2),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoRow(Pedido pedido) {
    final color = _colorEstado(pedido.estado);
    final detalle = pedido.items
        .map((i) => '${i.nombreProducto} x${i.cantidad}')
        .join(', ');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.isNotEmpty ? detalle : '#${pedido.id}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '\$${pedido.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _textoEstado(pedido.estado),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoPedido e) {
    switch (e) {
      case EstadoPedido.pendiente:
        return Colors.blue;
      case EstadoPedido.confirmado:
        return Colors.indigo;
      case EstadoPedido.enCamino:
        return Colors.orange;
      case EstadoPedido.entregado:
        return Colors.green;
      case EstadoPedido.cancelado:
        return Colors.red;
    }
  }

  String _textoEstado(EstadoPedido e) {
    return e.toString().split('.').last.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => ' ${m.group(0)}',
        );
  }

  Widget _bottomNavItem(IconData icon, String label, int index, BuildContext context) {
    return IconButton(
      onPressed: () {
        switch (index) {
          case 0:
            break;
          case 1:
            context.push('/admin/pedidos');
            break;
          case 2:
            context.push('/admin/productos');
            break;
          case 3:
            context.push('/admin/promos');
            break;
          case 4:
            context.push('/admin/sorteos');
            break;
        }
      },
      icon: Icon(icon, color: const Color(0xFF0891B2)),
    );
  }
}
