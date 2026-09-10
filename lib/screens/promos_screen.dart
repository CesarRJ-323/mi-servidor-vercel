import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/widgets/coupon_shape.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

class PromosScreen extends ConsumerWidget {
  const PromosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          // Header con gradiente diagonal + patrón de tokens
          Container(
            decoration: const BoxDecoration(gradient: AppColors.brandGradient),
            padding:
                const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text(
                    '←',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                const Text(
                  'Promociones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),

          // Lista de cupones — datos combinados de Firestore (promos + descuentos)
          Expanded(
            child: StreamBuilder<List<Promo>>(
              stream: ref.watch(promoRepositoryProvider).streamPromocionesCombinadas(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final promos = snapshot.data ?? [];
                if (promos.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay promociones disponibles',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: promos.length,
                  itemBuilder: (context, index) {
                    final promo = promos[index];
                    return CouponCard(
                      promocion: _promoToMap(promo),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Convierte un Promo del modelo a Map para el CouponCard.
Map<String, dynamic> _promoToMap(Promo p) {
  final String badgeText;
  final Color badgeColor;

  switch (p.tipo) {
    case '2x1':
      badgeText = '2x1';
      badgeColor = const Color(0xFFE5484D);
      break;
    case 'monto_fijo':
      badgeText = '-\$${p.valor.toStringAsFixed(0)}';
      badgeColor = const Color(0xFFFF7A45);
      break;
    case 'porcentaje':
    default:
      badgeText = '-${p.valor.toInt()}%';
      badgeColor = const Color(0xFF2EAA6E);
      break;
  }

  final String vigencia = p.duracion.isNotEmpty
      ? 'Válido: ${p.duracion}'
      : 'Válido hasta: ${p.fechaCreacion != null ? "${p.fechaCreacion!.toLocal()}".split('.')[0] : "indefinido"}';

  return {
    'titulo': p.nombre,
    'descripcion': p.descripcion,
    'badge': badgeText,
    'badgeColor': badgeColor,
    'vigencia': vigencia,
    'codigo': null,
  };
}

/// Card de promo con forma de cupón real: muescas circulares a los
/// costados (línea de recorte), gradiente por tipo de promo y código
/// con borde punteado tipo ticket.
class CouponCard extends StatelessWidget {
  final Map<String, dynamic> promocion;

  const CouponCard({super.key, required this.promocion});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = promocion['badgeColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: ClipPath(
        clipper: CouponClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera coloreada del cupón
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      badgeColor.withValues(alpha: 0.14),
                      badgeColor.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        promocion['titulo'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Text(
                        promocion['badge'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Línea de recorte con muescas
              const CouponDivider(),

              // Cuerpo
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promocion['descripcion'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Fila flexible: la vigencia puede encoger y el chip
                    // de código puede ir a segunda línea — sin overflow.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            promocion['vigencia'],
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (promocion['codigo'] != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4),
                                  style: BorderStyle.solid,
                                  width: 1,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.chip),
                              ),
                              child: Text(
                                promocion['codigo'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
