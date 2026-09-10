import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';

/// Selector de producto para descuento individual: buscador en vivo
/// sobre la colección `productos`. Al seleccionar, cierra el menú y
/// devuelve el producto elegido.
///
/// OPTIMIZADO: filtra SERVER-SIDE con nombre_lower (range query)
/// en vez de descargar todos los productos y filtrar en cliente.
/// cloud_firestore 6.x no expone .select() para streams, así que
/// usamos orderBy + limit y filtrado server-side.
Future<({String id, String nombre})?> seleccionarProducto(
  BuildContext context,
) async {
  return showModalBottomSheet<({String id, String nombre})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Elegí el producto',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setModal(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto por nombre...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _ProductSearchStream(query: query),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Builder separado para el StreamBuilder de búsqueda de productos.
/// Filtra server-side con range query sobre nombre_lower.
class _ProductSearchStream extends StatelessWidget {
  final String query;

  const _ProductSearchStream({required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();

    Stream<QuerySnapshot<Map<String, dynamic>>> stream;
    if (q.isEmpty) {
      // Sin búsqueda: traer los primeros 50 productos ordenados por nombre.
      stream = FirebaseFirestore.instance
          .collection('productos')
          .orderBy('nombre')
          .limit(50)
          .snapshots();
    } else {
      // Range query server-side: solo productos que empiezan con q.
      // Usa nombre_lower indexado para evitar full-collection scan.
      final end = '$q\uffff';
      stream = FirebaseFirestore.instance
          .collection('productos')
          .where('nombre_lower', isGreaterThanOrEqualTo: q)
          .where('nombre_lower', isLessThan: end)
          .orderBy('nombre_lower')
          .limit(50)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
              child: Text('Error al buscar productos.',
                  style: TextStyle(color: AppColors.textMuted)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Sin resultados',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final nombre = (d['nombre'] ?? '').toString();
            final categoria = (d['categoria'] ?? '').toString();
            final urlImagen = (d['url_imagen'] ?? '').toString();
            return ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: urlImagen.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          urlImagen,
                          fit: BoxFit.cover,
                          cacheWidth: 84, // 2x display (42px)
                          errorBuilder: (_, _, _) => const Icon(
                              Icons.fastfood_rounded,
                              color: AppColors.textMuted),
                        ),
                      )
                    : const Icon(Icons.fastfood_rounded,
                        color: AppColors.textMuted),
              ),
              title: Text(
                nombre,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: categoria.isNotEmpty
                  ? Text(
                      categoria,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () => Navigator.pop(
                context,
                (
                  id: docs[i].id,
                  nombre: nombre,
                ),
              ),
            );
          },
        );
      },
    );
  }
}