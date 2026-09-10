import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

class AdminPromosScreen extends ConsumerWidget {
  const AdminPromosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(promosAdminStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promociones'),
        backgroundColor: const Color(0xFF2A0800),
        actions: [
          IconButton(
            onPressed: () => context.push('/admin/promo'),
            icon: const Icon(Icons.add),
            tooltip: 'Agregar promoción',
          ),
        ],
      ),
      body: Column(
        children: [
          // Configuración de tokens (solo informativo)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración de Tokens',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A0800),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 60,
                        height: 30,
                        child: ColoredBox(
                          color: Color(0xFF0891B2),
                          child: Center(
                            child: Text(
                              '1 TOKEN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('= 1 producto comprado'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Los tokens se acumulan automáticamente por cada producto adquirido. No configurable.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Lista de promociones (en vivo desde Firebase)
          Expanded(
            child: promosAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                  child: Text('Error al cargar promociones.')),
              data: (promos) {
                if (promos.isEmpty) {
                  return const Center(
                    child: Text('No hay promociones. Toca + para crear.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: promos.length,
                  itemBuilder: (context, index) =>
                      _buildPromoCard(context, ref, promos[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(
      BuildContext context, WidgetRef ref, Promo promo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          promo.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          promo.descripcion.isNotEmpty
              ? promo.descripcion
              : 'Sin descripción',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: promo.activa
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            promo.activa ? 'Activa' : 'Inactiva',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: promo.activa ? Colors.green : Colors.grey,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo: ${_tipoTxt(promo.tipo)}'),
                Text('Valor: ${promo.valor}'),
                Text('Aplicar a: ${promo.aplicarA}'),
                Text('Duración: ${promo.duracion}'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.push(
                        '/admin/promo',
                        extra: promo,
                      ),
                      child: const Text('Editar'),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(promoRepositoryProvider)
                          .actualizarPromo(promo.id, {'activa': !promo.activa}),
                      child: Text(
                        promo.activa ? 'Desactivar' : 'Activar',
                        style: TextStyle(
                          color: promo.activa ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Borrar promoción'),
                            content: Text('¿Borrar "${promo.nombre}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Borrar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(promoRepositoryProvider)
                              .eliminarPromo(promo.id);
                        }
                      },
                      child: const Text('Borrar',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tipoTxt(String tipo) {
    switch (tipo) {
      case 'porcentaje':
        return 'Porcentaje (%)';
      case '2x1':
        return '2x1';
      case 'monto_fijo':
        return 'Monto fijo';
      default:
        return tipo;
    }
  }
}
