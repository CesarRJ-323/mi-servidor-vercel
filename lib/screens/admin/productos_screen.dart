import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/producto_model.dart';
import 'package:delivery_app_v2/models/categoria_model.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  bool showNewProductForm = false;

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Productos'),
        backgroundColor: const Color(0xFF2A0800),
        actions: [
          IconButton(
            onPressed: () =>
                setState(() => showNewProductForm = !showNewProductForm),
            icon: Icon(showNewProductForm ? Icons.close : Icons.add),
          ),
        ],
      ),
      floatingActionButton: showNewProductForm
          ? null
          : FloatingActionButton(
              onPressed: () => setState(() => showNewProductForm = true),
              backgroundColor: const Color(0xFF0891B2),
              child: const Icon(Icons.add),
            ),
      body: showNewProductForm
          ? _NuevoProductoForm(onClose: () => setState(() => showNewProductForm = false))
          : productosAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Error al cargar productos.')),
              data: (productos) {
                if (productos.isEmpty) {
                  return const Center(
                      child: Text('No hay productos. Toca + para agregar.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productos.length,
                  itemBuilder: (context, index) =>
                      _buildProductoCard(productos[index]),
                );
              },
            ),
    );
  }

  Widget _buildProductoCard(Producto producto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/admin/producto', extra: producto),
        leading: producto.urlImagen.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  producto.urlImagen,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  errorBuilder: (_, _, _) => _iconoCategoria(producto),
                ),
              )
            : CircleAvatar(
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                child: Text(
                  producto.categoria.isNotEmpty
                      ? (categoriasCatalogo
                          .firstWhere(
                            (c) => c.id == producto.categoria,
                            orElse: () => categoriasCatalogo.first,
                          )
                          .icon)
                      : '📦',
                  style: const TextStyle(fontSize: 22),
                ),
        ),
        title: Text(producto.nombre),
        subtitle: Text(
          '\$${producto.precioBase} • ${_nombreCategoria(producto.categoria)}',
        ),
        // Editar + disponible switch
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: producto.disponible,
              onChanged: (v) async {
                // Optimistically update + wait for Firestore to confirm.
                // evita el doble-toggle que ocurría con update() en vez de set(merge: true).
                await ref
                    .read(productoRepositoryProvider)
                    .actualizarProducto(producto.id, {'disponible': v});
              },
              activeThumbColor: const Color(0xFF0891B2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            // Editar
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  color: Color(0xFF0891B2)),
              tooltip: 'Editar producto',
              onPressed: () =>
                  context.push('/admin/producto', extra: producto),
            ),
            // Borrar con confirmación
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red),
              tooltip: 'Eliminar producto',
              onPressed: () => _confirmarBorrar(producto),
            ),
          ],
        ),
      ),
    );
  }

  /// Borra el producto con confirmación (evita toques accidentales).
  Future<void> _confirmarBorrar(Producto producto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Borrar producto?'),
        content: Text(
            'Se eliminará "\${producto.nombre}" permanentemente. '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(productoRepositoryProvider)
          .eliminarProducto(producto.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"\${producto.nombre}" eliminado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _iconoCategoria(Producto producto) {
    return CircleAvatar(
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      child: Text(
        producto.categoria.isNotEmpty
            ? (categoriasCatalogo
                .firstWhere(
                  (c) => c.id == producto.categoria,
                  orElse: () => categoriasCatalogo.first,
                )
                .icon)
            : '📦',
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  String _nombreCategoria(String id) {
    final cat = categoriasCatalogo.where((c) => c.id == id).toList();
    return cat.isEmpty ? id : cat.first.nombre;
  }
}

/// Formulario de alta de producto (guarda en Firebase).
class _NuevoProductoForm extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const _NuevoProductoForm({required this.onClose});

  @override
  ConsumerState<_NuevoProductoForm> createState() => _NuevoProductoFormState();
}

class _NuevoProductoFormState extends ConsumerState<_NuevoProductoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  String? _categoriaSel;
  bool _descuento = false;
  final _descPctCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _descCtrl.dispose();
    _imgCtrl.dispose();
    _descPctCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuevo Producto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2A0800),
              ),
            ),
            const SizedBox(height: 16),

            // Nombre
            _buildTextField(_nombreCtrl, 'Nombre del producto',
                'Ej: Hamburguesa Especial', true),
            const SizedBox(height: 16),

            // Precio
            _buildTextField(
                _precioCtrl, 'Precio base', '\$0', true, numerico: true),
            const SizedBox(height: 16),

            // Categoría (obligatoria, coincide con el cliente)
            DropdownButtonFormField<String>(
              initialValue: _categoriaSel,
              decoration: InputDecoration(
                labelText: 'Categoría *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
              ),
              items: categoriasCatalogo
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.icon} ${c.nombre}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoriaSel = v),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Elegí una categoría' : null,
            ),
            const SizedBox(height: 16),

            // URL de imagen (sin Storage por ahora)
            _buildTextField(_imgCtrl, 'URL de imagen (opcional)',
                'https://...', false),
            const SizedBox(height: 16),

            // Descripción
            _buildTextField(
                _descCtrl, 'Descripción (opcional)', 'Ingredientes...',
                false, maxLines: 3),
            const SizedBox(height: 16),

            // Oferta
            Row(
              children: [
                Switch(
                  value: _descuento,
                  onChanged: (v) => setState(() => _descuento = v),
                  activeThumbColor: const Color(0xFF0891B2),
                ),
                const SizedBox(width: 8),
                const Text('¿Oferta activa?'),
                if (_descuento) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: _buildTextField(
                        _descPctCtrl, '%', '0', false),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0891B2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Guardar Producto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => widget.onClose(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, String placeholder, bool required,
      {bool numerico = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF775144),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType:
              numerico ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
          ),
          validator: required
              ? (v) =>
                  (v == null || v.isEmpty) ? 'Campo obligatorio' : null
              : null,
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(productoRepositoryProvider);
    await repo.crearProducto(
      Producto(
        id: '',
        nombre: _nombreCtrl.text.trim(),
        precioBase: double.tryParse(_precioCtrl.text) ?? 0,
        categoria: _categoriaSel!,
        descripcion: _descCtrl.text.trim(),
        urlImagen: _imgCtrl.text.trim(),
        descuentoActivo: _descuento,
        porcentajeDescuento:
            _descuento ? double.tryParse(_descPctCtrl.text) : null,
      ),
    );
    if (mounted) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto guardado en Firebase')),
      );
    }
  }
}
