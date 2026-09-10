import 'package:flutter/material.dart';
import 'package:delivery_app_v2/models/producto_model.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';

/// Card de producto rediseñada: foto con fondo neutral, badge de
/// descuento flotante, precio jerárquico (tachado + final en naranja)
/// y botón "+" circular con sombra de marca.
class ProductCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onAgregar;
  /// Mapa categoria -> % activo (stream en vivo de Firestore).
  final Map<String, int> descuentosCategoria;

  const ProductCard({
    super.key,
    required this.producto,
    required this.onAgregar,
    this.descuentosCategoria = const {},
  });

  Widget _buildImagen() {
    final url = producto.urlImagen;
    if (url.isEmpty) {
      return Container(
        color: AppColors.imageBg,
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood_rounded,
            size: 36, color: AppColors.textMuted),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.image),
      child: Container(
        color: AppColors.imageBg,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // ~2x el tamaño de render (80px lógico) para no decodificar de más.
          cacheWidth: 160,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.imageBg,
            alignment: Alignment.center,
            child: const Icon(Icons.fastfood_rounded,
                size: 36, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Descuento efectivo: propio del producto o el de su categoría.
    final pctEfectivo =
        producto.porcentajeEfectivo(descuentosCategoria);
    final conDescuento = pctEfectivo != null;
    final precioFinal = producto.precioEnVivo(descuentosCategoria);

    return Opacity(
      // Producto sin stock: la card se ve apagada pero legible.
      opacity: producto.disponible ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: _buildImagen(),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (producto.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        producto.descripcion,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (conDescuento) ...[
                          Text(
                            r'$' '${producto.precioBase.toInt()}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Badge de % OFF
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.chip),
                            ),
                            child: Text(
                              '-$pctEfectivo%',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Precio final: protagonista, en acento cálido.
                        Text(
                          r'$' '${precioFinal.toInt()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    if (!producto.disponible)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Sin stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Botón + circular flotante
            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: producto.disponible ? onAgregar : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: producto.disponible
                        ? AppColors.brandGradient
                        : const LinearGradient(
                            colors: [Colors.grey, Colors.grey]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: producto.disponible ? AppShadows.floating : null,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
