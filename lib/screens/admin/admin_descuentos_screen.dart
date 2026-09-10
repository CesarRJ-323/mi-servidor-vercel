import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/data/repositories/descuentos_repository.dart';
import 'package:delivery_app_v2/models/categoria_model.dart';
import 'package:delivery_app_v2/screens/admin/selector_producto.dart';

/// Panel admin de descuentos con dos pestañas:
///  - Por categoría: un % para TODA la clase de alimento.
///  - Por producto: buscador de producto concreto -> su propio descuento.
/// Prioridad al calcular: producto > categoría > precio base.
class AdminDescuentosScreen extends StatelessWidget {
  const AdminDescuentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DescuentosRepository();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Descuentos'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Por categoría'),
              Tab(text: 'Por producto'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _tabCategorias(context, repo),
            _tabProductos(context, repo),
          ],
        ),
      ),
    );
  }

  // ================= PESTAÑA 1: por categoría =================
  Widget _tabCategorias(BuildContext context, DescuentosRepository repo) {
    return StreamBuilder<Map<String, int>>(
      stream: repo.streamActivosPorCategoria(),
      builder: (context, snap) {
        final activos = snap.data ?? const {};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _InfoCard(
              texto: 'Elegí una categoría y el % de descuento. Se aplica en '
                  'vivo a TODOS los productos de esa clase. Si un producto '
                  'tiene descuento propio, tiene prioridad.',
            ),
            const SizedBox(height: 16),
            ...categoriasCatalogo.map((cat) {
              final pct = activos[cat.id];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child:
                          Text(cat.icon, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            pct != null ? '$pct% OFF activo' : 'Sin descuento',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: pct != null
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _editarCategoria(context, repo, cat),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pct != null
                            ? AppColors.primary
                            : AppColors.primarySoft,
                        foregroundColor: pct != null
                            ? Colors.white
                            : AppColors.primaryDark,
                        elevation: 0,
                      ),
                      child: Text(pct != null ? 'Editar' : 'Agregar'),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ================= PESTAÑA 2: por producto =================
  Widget _tabProductos(BuildContext context, DescuentosRepository repo) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('descuentos').snapshots(),
      builder: (context, snapDesc) {
        // descuentos por producto activos: productoId -> (pct, nombre)
        final porProducto = <String, ({int pct, String nombre})>{};
        for (final d in snapDesc.data?.docs ?? []) {
          final f = d.data();
          if (f['tipo'] == 'producto' && (f['activo'] ?? false)) {
            porProducto[f['producto_id'] as String] = (
              pct: (f['porcentaje'] ?? 0) as int,
              nombre: (f['producto_nombre'] ?? '') as String,
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _InfoCard(
              texto: 'Buscá el producto concreto y ponle SU descuento. '
                  'Tiene prioridad sobre el de su categoría.',
            ),
            const SizedBox(height: 16),

            // Botón: abre el buscador; al seleccionar, el menú se cierra
            // y se continúa con la configuración habitual del descuento.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final sel = await seleccionarProducto(context);
                  if (sel == null || !context.mounted) return;
                  _editarProducto(context, repo, sel.id, sel.nombre);
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Buscar producto para descontar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (porProducto.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Todavía no hay descuentos por producto.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...porProducto.entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.fastfood_rounded,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.value.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5)),
                              Text('${e.value.pct}% OFF activo',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger),
                          onPressed: () => repo.eliminarDeProducto(e.key),
                        ),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }

  // ============ Modal: descuento de una categoría ============
  Future<void> _editarCategoria(
    BuildContext context,
    DescuentosRepository repo,
    Categoria cat,
  ) async {
    await _modalDescuento(
      context,
      titulo: 'Descuento para ${cat.nombre}',
      inicialPct: null,
      inicialActivo: true,
      onGuardar: (pct, activo) =>
          repo.guardar(categoria: cat.id, porcentaje: pct, activo: activo),
    );
  }

  // ============ Modal: descuento de UN producto ============
  Future<void> _editarProducto(
    BuildContext context,
    DescuentosRepository repo,
    String productoId,
    String productoNombre,
  ) async {
    await _modalDescuento(
      context,
      titulo: 'Descuento para $productoNombre',
      inicialPct: null,
      inicialActivo: true,
      onGuardar: (pct, activo) => repo.guardarDeProducto(
        productoId: productoId,
        productoNombre: productoNombre,
        porcentaje: pct,
        activo: activo,
      ),
    );
  }

  Future<void> _modalDescuento(
    BuildContext context, {
    required String titulo,
    required int? inicialPct,
    required bool inicialActivo,
    required Future<void> Function(int pct, bool activo) onGuardar,
  }) async {
    final pctCtrl =
        TextEditingController(text: inicialPct?.toString() ?? '');
    bool activo = inicialActivo;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: pctCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje de descuento (0-100)',
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Descuento activo',
                      style: TextStyle(fontSize: 14.5)),
                  value: activo,
                  onChanged: (v) => setModal(() => activo = v),
                  activeThumbColor: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final pct = int.tryParse(pctCtrl.text.trim());
                          if (pct == null || pct < 0 || pct > 100) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Ingresá un porcentaje entre 0 y 100'),
                              ),
                            );
                            return;
                          }
                          await onGuardar(pct, activo);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String texto;
  const _InfoCard({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
