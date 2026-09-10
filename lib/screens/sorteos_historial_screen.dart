import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';

/// Historial de sorteos terminados (últimos 7 días) con sus ganadores.
/// Los anuncios viejos se purgan automáticamente a la semana.
class SorteosHistorialScreen extends ConsumerStatefulWidget {
  const SorteosHistorialScreen({super.key});

  @override
  ConsumerState<SorteosHistorialScreen> createState() =>
      _SorteosHistorialScreenState();
}

class _SorteosHistorialScreenState
    extends ConsumerState<SorteosHistorialScreen> {
  bool _purgoEnCurso = false;

  @override
  void initState() {
    super.initState();
    // Limpieza automática: al abrir el historial, borra sorteos de +7 días.
    _purgarViejos();
  }

  Future<void> _purgarViejos() async {
    if (_purgoEnCurso) return;
    _purgoEnCurso = true;
    try {
      await ref.read(sorteoRepositoryProvider).purgarAntiguos(dias: 7);
    } catch (_) {
      // Silencioso: la purga es best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final historialAsync = ref.watch(sorteosHistorialStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sorteos'),
        backgroundColor: const Color(0xFF2A0800),
        foregroundColor: Colors.white,
      ),
      body: historialAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('No se pudo cargar el historial.'),
        ),
        data: (sorteos) {
          if (sorteos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay sorteos finalizados.\n'
                  'Cuando terminemos uno, el ganador va a aparecer acá. 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorteos.length,
            itemBuilder: (context, index) =>
                _buildHistorialCard(sorteos[index]),
          );
        },
      ),
    );
  }

  Widget _buildHistorialCard(Sorteo s) {
    final fin = s.fechaFin;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: imagen + título + badge terminado
            Row(
              children: [
                s.imagenUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          s.imagenUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 96,
                          errorBuilder: (_, _, _) => const Text('🎁',
                              style: TextStyle(fontSize: 28)),
                        ),
                      )
                    : const Text('🎁', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Sorteo terminado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Premio
            Text(
              '🎁 ${s.premio}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            // Fecha de realización
            Text(
              fin != null
                  ? 'Realizado el ${fin.day}/${fin.month}/${fin.year}'
                  : 'Sorteo finalizado',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const Divider(height: 18),
            // Ganadores
            const Text(
              '🏆 Ganador(es):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            ...s.ganadores.map(
              (g) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '🎉 $g',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
