import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/models/categoria_model.dart';

/// Chips horizontales de categorías para el home.
/// Extracción de home_screen.dart Fase 4.1.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key});

  static final List<Map<String, dynamic>> categorias = categoriasCatalogo
      .map((c) => {...c.toMap(), 'imagen': c.imagen})
      .toList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categorias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = categorias[index];
          return GestureDetector(
            onTap: () => context.push('/category/${cat['id']}'),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.4,
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: Image.asset(
                          cat['imagen'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(cat['icon'],
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['nombre'],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
