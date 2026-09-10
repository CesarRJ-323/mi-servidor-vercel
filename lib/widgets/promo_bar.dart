import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

/// Banner de promociones rotativo, con presencia fuerte y SIN ruido de
/// emojis: icono de regalo en cápsula, texto en dos niveles y pill
/// Un solo acento visual, como la sección de sorteos.
class PromoBar extends ConsumerStatefulWidget {
  const PromoBar({super.key});

  @override
  ConsumerState<PromoBar> createState() => _PromoBarState();
}

class _PromoBarState extends ConsumerState<PromoBar> {
  int _indiceActual = 0;
  Timer? _rotacionTimer;

  // Datos mock FALLBACK (solo se usan si Firestore no responde).
  static final List<(String, String)> _mockPromos = [
    ('20% OFF', 'en Cereales'),
  ];

  /// Etiquetas legibles para categorías (mirror del PromoRepository).
  static const Map<String, String> _categoriaLabels = {
    'cereales': 'Cereales',
    'verduleria': 'Verdulería',
    'frutas': 'Frutas',
    'jugos': 'Jugos Naturales',
    'postres': 'Postres Artesanales',
    'bebidas': 'Bebidas',
  };

  void _iniciarRotacion(int count) {
    // Cancelar timer anterior ANTES de crear uno nuevo (evita leaks
    // y setState post-dispose).
    _rotacionTimer?.cancel();
    _rotacionTimer = null;

    if (count <= 1) return;

    // Solo activar rotación si el widget sigue montado
    if (!mounted) return;

    _rotacionTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !context.mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _indiceActual = (_indiceActual + 1) % count;
      });
    });
  }

  @override
  void dispose() {
    _rotacionTimer?.cancel();
    _rotacionTimer = null;
    super.dispose();
  }

  String _formatearDestacado(Promo p) {
    switch (p.tipo) {
      case '2x1':
        return '2x1';
      case 'monto_fijo':
        return '-\$${p.valor.toInt()}';
      case 'porcentaje':
      default:
        return '-${p.valor.toInt()}%';
    }
  }

  /// Extrae un texto legible de la categoría o producto para el banner secundario.
  String _formatearResto(Promo p) {
    final nombre = p.nombre;
    final desc = p.descripcion;

    // Si la promo tiene aplicar_a, extraer la categoría/producto para
    // mostrar algo como "en Bebidas" o "en Café Express".
    final cid = p.categoriaId;
    final pid = p.productoId;

    if (cid != null && cid.isNotEmpty) {
      final label = _categoriaLabels[cid] ?? cid.toUpperCase();
      // Si el nombre ya incluye el label, no repetir.
      if (!nombre.toLowerCase().contains(label.toLowerCase())) {
        return 'en $label';
      }
      return label;
    }
    if (pid != null && pid.isNotEmpty) {
      return 'en $pid';
    }

    if (desc.isNotEmpty) {
      final limpia = desc.replaceFirst(RegExp(r'^Descuento\s+'), '').trim();
      return limpia.length > 30 ? '${limpia.substring(0, 30)}...' : limpia;
    }
    return nombre;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Promo>>(
      stream: ref.watch(promoRepositoryProvider).streamPromocionesCombinadas(),
      builder: (context, snapshot) {
        List<Promo> promos;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          promos = snapshot.data!;
          _iniciarRotacion(promos.length);
        } else {
          // Sin datos de Firestore, usar mock mínimo.
          _indiceActual = _indiceActual % _mockPromos.length;
          _iniciarRotacion(_mockPromos.length);
          return _buildBanner(
              context, _mockPromos[_indiceActual].$1, _mockPromos[_indiceActual].$2);
        }

        if (promos.isEmpty) return const SizedBox.shrink();

        _indiceActual = _indiceActual % promos.length;

        final destacado = _formatearDestacado(promos[_indiceActual]);
        final resto = _formatearResto(promos[_indiceActual]);

        return _buildBanner(context, destacado, resto);
      },
    );
  }

  Widget _buildBanner(BuildContext context, String destacado, String resto) {
    return GestureDetector(
      onTap: () => context.push('/promos'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF7A45), Color(0xFFFF9D2E)],
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono de regalo en cápsula de vidrio (único acento).
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // Texto: destacado bold + resto
            Expanded(
              child: SizedBox(
                height: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        destacado,
                        key: ValueKey<int>(_indiceActual),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        resto,
                        key: ValueKey('r$_indiceActual'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Flecha -> invita a /promos
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}