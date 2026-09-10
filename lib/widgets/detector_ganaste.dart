import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/services/notificaciones_ganaste.dart';
import 'package:delivery_app_v2/data/repositories/sorteo_repository.dart';
import 'package:delivery_app_v2/screens/home_screen.dart' show ganasteNotificadoProvider;

/// Widget invisible que detecta si el usuario logueado es ganador de un
/// sorteo terminado hace <48h y, si corresponde, dispara la notificación
/// local "¡Ganaste!". Toda la mutación de providers ocurre en
/// post-frame callbacks (nunca durante el build).
class DetectorGanaste extends ConsumerStatefulWidget {
  const DetectorGanaste({super.key});

  @override
  ConsumerState<DetectorGanaste> createState() => _DetectorGanasteState();
}

class _DetectorGanasteState extends ConsumerState<DetectorGanaste> {
  bool _procesando = false;

  // Cache de la última purga para evitar disparar múltiples
  // purgas de sorteos antiguos en cada rebuild del HomeScreen.
  static DateTime? _ultimaPurga;

  @override
  Widget build(BuildContext context) {
    // Se reconstruye cuando cambia el login o los sorteos.
    final usuario = ref.watch(usuarioActualProvider).valueOrNull;
    final sorteos = ref.watch(sorteosActivosStreamProvider).valueOrNull;
    final notificados = ref.watch(ganasteNotificadoProvider);

    // Purga automática: sorteos terminados hace +24h se borran de Firebase.
    // Se ejecuta una vez por día como máximo (cache en _ultimaPurga)
    // para no disparar múltiples purgas en rebuilds frecuentes.
    if (sorteos != null && _deboPurgar()) {
      _ultimaPurga = DateTime.now();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await SorteoRepository().purgarAntiguos(horas: 24);
        } catch (_) {}
      });
    }

    if (usuario != null && sorteos != null && !_procesando) {
      final miNombre = usuario.nombre.trim().toLowerCase();
      for (final s in sorteos) {
        if (!s.finalizado || notificados.contains(s.id)) continue;
        final hace48h = s.fechaFin != null &&
            DateTime.now().difference(s.fechaFin!).inHours < 48;
        if (!hace48h) continue;
        if (!s.ganadores.any((g) => g.trim().toLowerCase() == miNombre)) {
          continue;
        }

        // Ganador encontrado: notificar FUERA del build (post-frame).
        final id = s.id;
        final titulo = s.titulo;
        final premio = s.premio;
        _procesando = true; // evita doble disparo mientras corre el async
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await NotificacionesGanaste.notificarGanaste(
              nombreSorteo: titulo,
              premio: premio,
            );
          } finally {
            if (mounted) {
              ref.read(ganasteNotificadoProvider.notifier).update(
                  (set) => {...set, id});
              _procesando = false;
            }
          }
        });
        break; // una notificación por pasada
      }
    }

    return const SizedBox.shrink();
  }

  /// La purga se ejecuta como máximo una vez cada 6 horas.
  bool _deboPurgar() {
    if (_ultimaPurga == null) return true;
    return DateTime.now().difference(_ultimaPurga!).inHours >= 6;
  }
}