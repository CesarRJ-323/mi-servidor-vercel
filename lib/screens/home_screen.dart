import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/widgets/detector_ganaste.dart';
import 'package:delivery_app_v2/widgets/hero_section.dart';
import 'package:delivery_app_v2/widgets/category_chips.dart';
import 'package:delivery_app_v2/widgets/promo_bar.dart';
import 'package:delivery_app_v2/widgets/recent_orders.dart';
import 'package:delivery_app_v2/widgets/sorteo_section.dart';
import 'package:delivery_app_v2/widgets/help_footer.dart';

/// Sorteos cuya notificación "ganaste" ya se mostró en esta instalación.
final ganasteNotificadoProvider =
    StateProvider<Set<String>>((ref) => {});

/// Home principal: hero verde + categorías + promos + pedidos + sorteos.
/// Refactorizado Fase 4.1: descomposición de God Widget (1066 → ~45 líneas).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Detector invisible: dispara la notificación "¡Ganaste!"
          SliverToBoxAdapter(child: const DetectorGanaste()),

          // Hero verde con ubicación + buscador + acciones
          SliverToBoxAdapter(child: const HeroSection()),

          // Contenido sobre fondo claro
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 18),
                  // Chips de categorías
                  CategoryChips(),
                  SizedBox(height: 14),
                  // Barra de promociones
                  PromoBar(),
                  SizedBox(height: 16),
                  // Mis compras recientes
                  RecentOrders(),
                  SizedBox(height: 20),
                  // Sorteos
                  SorteoSection(),
                  SizedBox(height: 20),
                  // Footer de ayuda
                  HelpFooter(),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
