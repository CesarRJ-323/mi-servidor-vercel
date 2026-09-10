import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/widgets/modal_direccion.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/providers/cart_provider.dart';

/// Header verde con ubicación + buscador + acciones (admin, carrito, login).
/// Extracción de home_screen.dart Fase 4.1.
class HeroSection extends ConsumerWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.cantidad);
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
          child: Column(
            children: [
              // Fila: ubicación + acciones
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entregar en',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                        Builder(builder: (context) {
                          final usuario =
                              ref.watch(usuarioActualProvider).valueOrNull;
                          final direccion = (usuario != null &&
                                  usuario.direccion.trim().isNotEmpty)
                              ? usuario.direccion.trim()
                              : 'Tu dirección 📍';
                          return GestureDetector(
                            onTap: usuario == null
                                ? null
                                : () async {
                                    final guardo =
                                        await mostrarModalDireccion(
                                      context,
                                      usuario: usuario,
                                      onGuardar:
                                          (dir, maps, casa) async {
                                        await ref
                                            .read(usuarioRepositoryProvider)
                                            .actualizarUsuario(
                                          usuario.uid,
                                          {
                                            'direccion': dir,
                                            'maps_url': maps,
                                            'descripcion_casa': casa,
                                          },
                                        );
                                        ref.invalidate(usuarioActualProvider);
                                      },
                                    );
                                    if (guardo && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Dirección actualizada ✅'),
                                          backgroundColor: AppColors.primary,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    direccion,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (usuario != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 14),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  if (ref.watch(isAdminProvider))
                    IconButton(
                      onPressed: () => context.go('/admin'),
                      icon: const Icon(Icons.admin_panel_settings,
                          color: Colors.white),
                      tooltip: 'Panel de administración',
                    ),
                  // Carrito con badge
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.push('/cart'),
                        icon: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.white),
                      ),
                      if (totalItems > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$totalItems',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  // Invitado: iniciar sesión. Logueado: salir.
                  TextButton(
                    onPressed: isLoggedIn
                        ? () async {
                            await ref
                                .read(authRepositoryProvider)
                                .cerrarSesion();
                            if (context.mounted) context.go('/home');
                          }
                        : () => context.push('/login'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      isLoggedIn ? 'Salir' : 'Iniciar sesión',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Buscador flotante blanco
              GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.search),
                    boxShadow: AppShadows.floating,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar productos...',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
