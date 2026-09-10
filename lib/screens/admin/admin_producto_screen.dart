import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/producto_model.dart';

/// Alta (y edición) de productos desde el panel admin.
/// Guarda en Firestore (colección `productos`). La imagen es una URL externa
/// (sin Storage): el admin pega el link de la foto; el campo ya queda listo
/// para usar Firebase Storage más adelante.
class AdminProductoScreen extends ConsumerStatefulWidget {
  final Producto? producto; // null = crear, si no = editar

  const AdminProductoScreen({super.key, this.producto});

  @override
  ConsumerState<AdminProductoScreen> createState() => _AdminProductoScreenState();
}

class _AdminProductoScreenState extends ConsumerState<AdminProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _precioTokensCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _categorias = ['cereales', 'bebidas', 'frutas', 'jugos', 'postres'];
  String _categoria = 'cereales';
  bool _descuentoActivo = false;
  bool _requiereTokens = false;
  final _ticketsRewardCtrl = TextEditingController();
  final _porcCtrl = TextEditingController();
  bool _disponible = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p != null) {
      _nombreCtrl.text = p.nombre;
      _precioCtrl.text = p.precioBase.toInt().toString();
      _precioTokensCtrl.text = p.precioTokens.toString();
      _descCtrl.text = p.descripcion;
      _urlCtrl.text = p.urlImagen;
      _categoria = p.categoria.isNotEmpty ? p.categoria : 'cereales';
      _descuentoActivo = p.descuentoActivo;
      _requiereTokens = p.requiereTokens;
      _porcCtrl.text = p.porcentajeDescuento?.toInt().toString() ?? '';
      _ticketsRewardCtrl.text = p.ticketsReward.toString();
      _disponible = p.disponible;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _precioTokensCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _porcCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(productoRepositoryProvider);
      final producto = Producto(
        id: widget.producto?.id ?? '',
        nombre: _nombreCtrl.text.trim(),
        precioBase: double.tryParse(_precioCtrl.text) ?? 0,
        descripcion: _descCtrl.text.trim(),
        urlImagen: _urlCtrl.text.trim(),
        categoria: _categoria,
        descuentoActivo: _descuentoActivo,
        porcentajeDescuento: _descuentoActivo
            ? (double.tryParse(_porcCtrl.text) ?? 0)
            : null,
        disponible: _disponible,
        ticketsReward: int.tryParse(_ticketsRewardCtrl.text) ?? 0,
        stock: widget.producto?.stock ?? 0,
        requiereTokens: _requiereTokens,
        precioTokens: int.tryParse(_precioTokensCtrl.text) ?? 0,
      );

      if (widget.producto == null) {
        await repo.crearProducto(producto);
      } else {
        await repo.actualizarProducto(producto.id, producto.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.producto == null
                ? 'Producto creado ✅'
                : 'Producto actualizado ✅'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.producto == null ? 'Nuevo producto' : 'Editar producto'),
        backgroundColor: const Color(0xFF2A0800),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _campo('Nombre *', _nombreCtrl, 'Ingresá el nombre'),
              const SizedBox(height: 15),
              _campo('Precio base *', _precioCtrl, 'Ej. 120',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 15),
              _campo('Descripción', _descCtrl, 'Opcional', maxLines: 2),
              const SizedBox(height: 15),

              // Categoría
              const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 15),

              // URL de imagen (Cloudinary, Supabase, etc.) + preview en vivo
              _campo(
                'URL de imagen (opcional)',
                _urlCtrl,
                'Pegá el link https de la foto (Cloudinary, Supabase...)',
                keyboardType: TextInputType.url,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null; // opcional
                  final uri = Uri.tryParse(t);
                  if (uri == null || uri.scheme != 'https') {
                    return 'Debe ser una URL https (Cloudinary, Supabase...)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Preview: si la URL es https válida, muestra la foto.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _urlCtrl,
                builder: (context, value, _) {
                  final url = value.text.trim();
                  final uri = Uri.tryParse(url);
                  final valida =
                      uri != null && uri.scheme == 'https' && url.isNotEmpty;
                  if (!valida) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              cacheWidth: 144,
                              errorBuilder: (_, _, _) => const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_rounded,
                                      color: Colors.grey),
                                  SizedBox(height: 2),
                                  Text('No carga',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Así la ven los clientes. Si dice "No carga", '
                            'revisá que el link sea público (abrilo en el '
                            'navegador en modo incógnito).',
                            style: TextStyle(
                                fontSize: 11.5, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),

              // Descuento
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Tiene descuento?'),
                value: _descuentoActivo,
                onChanged: (v) => setState(() => _descuentoActivo = v!),
              ),
              if (_descuentoActivo)
                _campo('Porcentaje de descuento', _porcCtrl, 'Ej. 20',
                    keyboardType: TextInputType.number),
              const SizedBox(height: 10),

              // Disponible
              // Tickets reward
              _campo(
                'Tickets que se otorgan al comprar este producto',
                TextEditingController(),
                'Ej. 2',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null) return 'Ingrese un número entero';
                  if (n < 0) return 'Debe ser >= 0';
                  if (n > 100) return 'Máximo 100';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible (en stock)'),
                value: _disponible,
                onChanged: (v) => setState(() => _disponible = v!),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.producto == null ? 'Crear producto' : 'Guardar cambios',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, String hint,
      {TextInputType? keyboardType,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: validator ??
              (v) {
                if (label.endsWith('*') && (v == null || v.trim().isEmpty)) {
                  return 'Requerido';
                }
                return null;
              },
        ),
      ],
    );
  }
}
