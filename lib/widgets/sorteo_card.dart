import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';

/// Card individual de un sorteo en el home.
/// Extracción de home_screen.dart Fase 4.1.
class SorteoCard extends ConsumerWidget {
  final Sorteo sorteo;
  final bool participando;
  final String nombreUsuario;

  const SorteoCard({
    super.key,
    required this.sorteo,
    this.participando = false,
    this.nombreUsuario = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = sorteo;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
      child: Row(
        children: [
          // Imagen (URL externa o emoji)
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.all(10),
            child: s.imagenUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      s.imagenUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, _, _) => _sorteoPlaceholder(),
                    ),
                  )
                : _sorteoPlaceholder(),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (s.descripcion.isNotEmpty)
                    Text(
                      s.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    s.premio.replaceAll('🎁', '').trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (s.finalizado)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (context) {
                            final usuario =
                                ref.watch(usuarioActualProvider).valueOrNull;
                            final yoGane = usuario != null &&
                                s.ganadores.any((g) =>
                                    g.trim().toLowerCase() ==
                                    usuario.nombre.trim().toLowerCase());
                            return yoGane
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD54F),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '🏆 ¡GANASTE!',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF5D4037),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '🏁 Sorteo terminado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange,
                                    ),
                                  );
                          }),
                          const SizedBox(height: 2),
                          ...s.ganadores.map(
                            (g) => Text(
                              '🏆 Ganador: $g',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (participando)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF4CAF50)),
                          SizedBox(width: 4),
                          Text(
                            'Participando',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Sorteo: ${s.fechaSorteo.day}/${s.fechaSorteo.month}/${s.fechaSorteo.year} • Tocá para participar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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

  Widget _sorteoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text('🎁', style: TextStyle(fontSize: 32)),
    );
  }
}
