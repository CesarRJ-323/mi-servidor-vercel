import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/widgets/empty_state_card.dart';
import 'package:delivery_app_v2/widgets/status_badge.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/pedido_model.dart';

/// Sección "Mis compras recientes" del home.
/// Muestra empty state con CTA de login para invitados,
/// y lista de pedidos para usuarios logueados.
/// Extracción de home_screen.dart Fase 4.1.
class RecentOrders extends ConsumerWidget {
  const RecentOrders({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mis compras recientes',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildCompras(context, ref),
        ],
      ),
    );
  }

  Widget _buildCompras(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isLoggedInProvider)) {
      return EmptyStateCard(
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.primary,
        titulo: 'Todavía no tenés compras',
        subtitulo: 'Iniciá sesión para ver tus pedidos',
        actionText: 'Iniciar sesión',
        onAction: () => context.push('/login'),
      );
    }

    final pedidosAsync = ref.watch(pedidosUsuarioStreamProvider);

    return pedidosAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No se pudieron cargar las compras.',
          style: TextStyle(color: Colors.red[400], fontSize: 14),
        ),
      ),
      data: (pedidos) {
        if (pedidos.isEmpty) {
          return const EmptyStateCard(
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.primary,
            titulo: 'Todavía no tenés compras',
            subtitulo: 'Cuando hagas tu primer pedido va a aparecer acá',
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pedidos.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = pedidos[index];
            final nombres = p.items
                .map((i) => '${i.nombreProducto} x${i.cantidad}')
                .join(', ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🛒 ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          nombres.isEmpty ? 'Pedido' : nombres,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: StatusBadge(
                      text: _estadoTexto(p.estado),
                      color: _estadoColor(p.estado),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _estadoTexto(EstadoPedido e) {
    switch (e) {
      case EstadoPedido.pendiente:
        return 'Pendiente';
      case EstadoPedido.confirmado:
        return 'Confirmado';
      case EstadoPedido.enCamino:
        return 'En camino';
      case EstadoPedido.entregado:
        return 'Entregado';
      case EstadoPedido.cancelado:
        return 'Cancelado';
    }
  }

  Color _estadoColor(EstadoPedido e) {
    switch (e) {
      case EstadoPedido.pendiente:
        return Colors.yellow[700]!;
      case EstadoPedido.confirmado:
        return Colors.blue;
      case EstadoPedido.enCamino:
        return Colors.orange;
      case EstadoPedido.entregado:
        return Colors.green;
      case EstadoPedido.cancelado:
        return Colors.red;
    }
  }
}
