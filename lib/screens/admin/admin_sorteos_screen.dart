import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';

/// Lista de sorteos para el panel admin (mismo estilo que promos):
/// el admin ve todos, puede crear (+), editar, activar/desactivar y borrar.
class AdminSorteosScreen extends ConsumerWidget {
  const AdminSorteosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sorteoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sorteos'),
        backgroundColor: const Color(0xFF2A0800),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => context.push('/admin/sorteo'),
            icon: const Icon(Icons.add),
            tooltip: 'Publicar sorteo',
          ),
        ],
      ),
      body: StreamBuilder<List<Sorteo>>(
        stream: repo.streamTodosLosSorteos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los sorteos.'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sorteos = snap.data!;
          if (sorteos.isEmpty) {
            return const Center(
              child: Text('No hay sorteos. Tocá + para publicar uno.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorteos.length,
            itemBuilder: (context, index) {
              final s = sorteos[index];
              return _SorteoAdminCard(
                sorteo: s,
                onEditar: () => context.push(
                  '/admin/sorteo',
                  extra: s,
                ),
                onRealizarSorteo: () async {
                  final confirmado = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Realizar sorteo'),
                      content: Text(
                          'Se elegirán ${s.cantidadGanadores} ganador(es) al azar '
                          'entre ${s.participantes.length} participante(s).\n'
                          'Esta acción no se puede deshacer.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sortear',
                              style:
                                  TextStyle(color: Color(0xFF667eea))),
                        ),
                      ],
                    ),
                  );
                  if (confirmado != true) return;
                  try {
                    final ganadores = await ref
                        .read(sorteoRepositoryProvider)
                        .realizarSorteo(
                          sorteoId: s.id,
                          cantidad: s.cantidadGanadores,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '🏆 Ganador(es): ${ganadores.join(', ')}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$e'.replaceAll('Exception: ', '')),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                onToggle: () async {
                  await ref.read(sorteoRepositoryProvider).actualizarSorteo(
                    s.id,
                    {'activo': !s.activo},
                  );
                },
                onBorrar: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Borrar sorteo'),
                      content: Text('¿Borrar "${s.titulo}"?'),
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
                    await ref.read(sorteoRepositoryProvider).eliminarSorteo(s.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SorteoAdminCard extends StatelessWidget {
  final Sorteo sorteo;
  final VoidCallback onEditar;
  final VoidCallback onRealizarSorteo;
  final VoidCallback onToggle;
  final VoidCallback onBorrar;

  const _SorteoAdminCard({
    required this.sorteo,
    required this.onEditar,
    required this.onRealizarSorteo,
    required this.onToggle,
    required this.onBorrar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: sorteo.imagenUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  sorteo.imagenUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  cacheWidth: 96, // ahorra RAM en gama baja
                  errorBuilder: (_, _, _) =>
                      const Text('🎁', style: TextStyle(fontSize: 28)),
                ),
              )
            : const Text('🎁', style: TextStyle(fontSize: 28)),
        title: Text(
          sorteo.titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sorteo.premio} • ${sorteo.fechaSorteo.day}/${sorteo.fechaSorteo.month}/${sorteo.fechaSorteo.year} • ${sorteo.cantidadGanadores} ganador(es)',
            ),
            // Ganadores visibles para el admin cuando el sorteo terminó.
            if (sorteo.finalizado && sorteo.ganadores.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...sorteo.ganadores.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          g,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: sorteo.finalizado
                ? Colors.orange.withValues(alpha: 0.15)
                : sorteo.activo
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            sorteo.finalizado
                ? 'Sorteo terminado'
                : sorteo.activo
                    ? 'Activo'
                    : 'Inactivo',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: sorteo.finalizado
                  ? Colors.orange
                  : sorteo.activo
                      ? Colors.green
                      : Colors.grey,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sorteo.descripcion.isNotEmpty)
                  Text(sorteo.descripcion),
                const SizedBox(height: 8),
                Text(
                  '👥 ${sorteo.participantes.length} participante(s)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // Ganadores o botón de realizar sorteo
                if (sorteo.finalizado) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🏆 Sorteo terminado — Ganador(es):',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...sorteo.ganadores.map(
                          (g) => Text('🎉 $g',
                              style: const TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: onRealizarSorteo,
                    icon: const Icon(Icons.casino),
                    label: Text(
                        'Realizar sorteo (${sorteo.cantidadGanadores} ganador/es)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onEditar,
                      child: const Text('Editar'),
                    ),
                    TextButton(
                      onPressed: onToggle,
                      child: Text(
                        sorteo.activo ? 'Desactivar' : 'Activar',
                        style: TextStyle(
                          color: sorteo.activo ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onBorrar,
                      child: const Text(
                        'Borrar',
                        style: TextStyle(color: Colors.red),
                      ),
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
}
