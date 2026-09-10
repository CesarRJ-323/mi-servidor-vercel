import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:delivery_app_v2/providers/cart_provider.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/services/mercado_pago_service.dart';
import 'package:delivery_app_v2/models/configuracion_pago_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_app_v2/models/pedido_model.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final totalPesos = items.where((i) => !i.requiereTokens).fold(0, (sum, i) => sum + i.subtotal);
    final totalTokens = items.where((i) => i.requiereTokens).fold(0, (sum, i) => sum + i.subtotal);

    // TODO: if you have shipping costs, add them to totalPesos
    final subtotalPesos = totalPesos;

    return Scaffold(
      body: Column(
        children: [
          // Banner superior
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const Text(
                      'Tu carrito',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? 'producto' : 'productos'}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Vaciar carrito'),
                          content: const Text('¿Eliminar todos los productos?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                            TextButton(
                              onPressed: () {
                                cartNotifier.vaciar();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Vaciar', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  )
                else
                  const SizedBox(width: 44),
              ],
            ),
            ],
            ),
          ),

          // Lista de items
          Expanded(
            child: items.isEmpty
                ? _buildEmptyCart(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CartItemWidget(
                        item: item,
                        onQuantityChanged: (nuevaCantidad) {
                          cartNotifier.cambiarCantidad(item.id, nuevaCantidad);
                        },
                        onRemove: () {
                          cartNotifier.eliminar(item.id);
                        },
                      );
                    },
                  ),
          ),

          // Resumen y checkout
          if (items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                children: [
                  if (totalPesos > 0) ...[
                    _buildSummaryRow('Subtotal (Pesos)', r'$' '$subtotalPesos'),
                    _buildSummaryRow('Envío', r'$0'),
                  ],
                  if (totalTokens > 0)
                    _buildSummaryRow('Subtotal (Tokens)', '🪙 $totalTokens'),
                  
                  const Divider(height: 20),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Problemas con el pago'),
                            content: FutureBuilder<ConfiguracionPago>(
                              future: FirebaseFirestore.instance
                                  .collection('configuracion')
                                  .doc('pago_alternativo')
                                  .get()
                                  .then((doc) => doc.exists ? ConfiguracionPago.fromJson(doc.data()!) : ConfiguracionPago(aliasPago: '', instrucciones: '', activo: false)),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Cargando...');
                                }
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }
                                final config = snapshot.data!;
                                if (!config.activo) {
                                  return const Text('El pago alternativo no está activo actualmente.');
                                }
                                return Text(
                                  'Si tenés problemas con el pago, transfiere a este alias de mercado pago \'${config.aliasPago}\' y esperá la confirmación.\n\n${config.instrucciones}',
                                );
                              },
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
                            ],
                          ),
                        );
                      },
                      child: const Text('¿Tenés problemas con el pago?'),
                    ),
                  ),
                  if (totalPesos > 0)
                    _buildSummaryRow('Total a pagar', r'$' '$totalPesos', isTotal: true),
                  if (totalTokens > 0)
                    _buildSummaryRow('Total en Tokens', '🪙 $totalTokens', isTotal: true),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          // Invitado -> pedir login antes del checkout.
                          if (!ref.read(isLoggedInProvider)) {
                            context.push('/login');
                            return;
                          }
                          try {
                            // 1. Create the order in Firestore first with 'pendiente' state
                            final user = FirebaseAuth.instance.currentUser!;
                            final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
                            final userData = userDoc.data() ?? {};
                            
                            final pedidoItems = items
                                .map((i) => PedidoItem(
                                      productoId: i.id,
                                      nombreProducto: i.nombre,
                                      cantidad: i.cantidad,
                                      precioUnitario: i.precio.toDouble(),
                                      promoAplicada: i.promoAplicada,
                                    ))
                                .toList();
                            
                            final pedido = Pedido(
                              id: '', // Firestore generates it
                              usuarioId: user.uid,
                              usuarioNombre: userData['nombre'] ?? user.displayName ?? '',
                              usuarioTelefono: userData['telefono'] ?? '',
                              usuarioWhatsapp: userData['whatsapp'] ?? '',
                              mapsUrl: userData['maps_url'] ?? '',
                              descripcionCasa: '',
                              items: pedidoItems,
                              subtotal: subtotalPesos.toDouble(),
                              total: totalPesos.toDouble(),
                              direccionEnvio: userData['direccion'] ?? '',
                              estado: EstadoPedido.pendiente,
                              fechaCreacion: DateTime.now(),
                            );
                            
                            final pedidoId = await ref.read(pedidoRepositoryProvider).crearPedido(pedido);

                            // 2. Create Mercado Pago preference with the real order ID
                            final preference = await MercadoPagoService.crearPreferencia(
                              titulo: 'Pedido Rapidiya',
                              items: [
                                for (final it in items)
                                  ItemMP(
                                    id: it.id,
                                    titulo: it.nombre,
                                    precioUnitario: it.precio.toDouble(),
                                    cantidad: it.cantidad,
                                    requiereTokens: it.requiereTokens,
                                  ),
                              ],
                              externalReference: pedidoId,
                              userId: user.uid,
                              userEmail: user.email ?? '',
                            );
                            if (preference.initPoint.startsWith('rapidiya://')) {
                              final path = preference.initPoint.replaceFirst('rapidiya:/', '');
                              context.go(path);
                            } else {
                              final Uri checkoutUrl = Uri.parse(preference.initPoint);
                              // Force open in Chrome (external browser) — the deep link
                              // rapidiya://pago/exito is registered as an App Link,
                              // so after payment MP redirects back to the app.
                              bool launched = await launchUrl(
                                checkoutUrl,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!launched) {
                                // Fallback para emuladores que no tengan un browser externo bien configurado
                                launched = await launchUrl(
                                  checkoutUrl,
                                  mode: LaunchMode.platformDefault,
                                );
                              }
                              if (!launched) {
                                throw MPException('No se pudo abrir el checkout de Mercado Pago');
                              }
                            }
                          } on MPException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.mensaje),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error inesperado: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          totalPesos == 0 && totalTokens > 0 
                            ? 'Pagar con Tokens 🪙'
                            : 'Pagar con Mercado Pago 💳',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 15,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black87 : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 15,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          const Text(
            'Tu carrito está vacío',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agregá productos desde las categorías',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Ver productos'),
          ),
        ],
      ),
    );
  }
}

class CartItemWidget extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
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
      child: Row(
        children: [
          // Emoji del producto
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(item.icono, style: const TextStyle(fontSize: 28)),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _quantityButton('−', () {
                        if (item.cantidad > 1) {
                          onQuantityChanged(item.cantidad - 1);
                        }
                      }),
                      const SizedBox(width: 12),
                      Text(
                        '${item.cantidad}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _quantityButton('+', () {
                        onQuantityChanged(item.cantidad + 1);
                      }),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r'$' '${item.subtotal}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón eliminar
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4757)),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton(String text, VoidCallback onPressed) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF667eea),
          ),
        ),
      ),
    );
  }
}
