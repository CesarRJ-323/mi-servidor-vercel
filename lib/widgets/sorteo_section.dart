import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/widgets/sorteo_card.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';

/// Sección de sorteos activos en el home.
/// Muestra los sorteos publicados por el admin y permite participar.
/// Extracción de home_screen.dart Fase 4.1.
class SorteoSection extends ConsumerWidget {
  const SorteoSection({super.key});

  // Anti-spam: timestamps de último tap por sorteoId para evitar
  // doble consumo de ticket por clics múltiples.
  static final Map<String, DateTime> _lastTapSorteo = {};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorteosAsync = ref.watch(sorteosActivosStreamProvider);
    final user = ref.watch(usuarioActualProvider).valueOrNull;
    final currentUid = ref.read(authStateProvider).value?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎁 Sorteos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/sorteos'),
                  icon: const Icon(Icons.history, size: 16,
                      color: AppColors.primaryDark),
                  label: const Text(
                    'Ver sorteos',
                    style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          sorteosAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No se pudieron cargar los sorteos.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            data: (sorteos) {
              if (sorteos.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'No hay sorteos activos por ahora.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                );
              }
              return ListView.builder(
                // ignore: deprecated_member_use
                cacheExtent: 300, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorteos.length,
                itemBuilder: (context, index) {
                  final s = sorteos[index];
                  return GestureDetector(
                    onTap: () {
                      if (!ref.read(isLoggedInProvider)) {
                        context.push('/login');
                        return;
                      }
                      if (s.finalizado) return;
                      // Anti-spam: evitar doble tap. El rate-limiter server-side
                      // también protege, pero el debounce mejora la UX.
                      _participar(context, ref, s);
                    },
                    child: SorteoCard(
                      sorteo: s,
                      participando: s.participantes
                          .any((p) => p.trim() == currentUid),
                      nombreUsuario: user?.nombre ?? '',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _participar(
    BuildContext context,
    WidgetRef ref,
    Sorteo s,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final nombre = ref.read(usuarioActualProvider).value?.nombre ?? 'Cliente';

    // Anti-spam: el rate-limiter server-side también protege, pero
    // el debounce mejora la UX (evita doble tap → consumo doble de ticket).
    final now = DateTime.now();
    final lastTap = _lastTapSorteo[s.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (now.difference(lastTap) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastTapSorteo[s.id] = now;

    try {
      final msg = await ref
          .read(sorteoRepositoryProvider)
          .participar(sorteoId: s.id, uid: user.uid, nombre: nombre);
      if (!context.mounted) return;

      // Si ya participa, mostrar en verde (info, no error).
      final esInfo = msg.toLowerCase().contains('inscripto') ||
          msg.toLowerCase().contains('inscrib') ||
          msg.toLowerCase().contains('particip');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: esInfo ? AppColors.primary : Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
