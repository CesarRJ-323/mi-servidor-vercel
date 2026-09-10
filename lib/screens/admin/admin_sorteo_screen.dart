import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';

/// Publicar (y editar) sorteos desde el panel admin.
/// Guarda en Firestore (colección `sorteos`). La imagen es una URL externa
/// (sin Storage): el admin pega el link del afiche/poster.
class AdminSorteoScreen extends ConsumerStatefulWidget {
  final Sorteo? sorteo; // null = crear

  const AdminSorteoScreen({super.key, this.sorteo});

  @override
  ConsumerState<AdminSorteoScreen> createState() => _AdminSorteoScreenState();
}

class _AdminSorteoScreenState extends ConsumerState<AdminSorteoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _premioCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  DateTime _fecha = DateTime.now().add(const Duration(days: 7));
  int _cantidadGanadores = 1;
  bool _activo = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final s = widget.sorteo;
    if (s != null) {
      _tituloCtrl.text = s.titulo;
      _descCtrl.text = s.descripcion;
      _premioCtrl.text = s.premio;
      _urlCtrl.text = s.imagenUrl;
      _fecha = s.fechaSorteo;
      _cantidadGanadores = s.cantidadGanadores;
      _activo = s.activo;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _premioCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(sorteoRepositoryProvider);
      final sorteo = Sorteo(
        id: widget.sorteo?.id ?? '',
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        premio: _premioCtrl.text.trim(),
        fechaSorteo: _fecha,
        imagenUrl: _urlCtrl.text.trim(),
        activo: _activo,
        creadoEn: widget.sorteo?.creadoEn ?? DateTime.now(),
        cantidadGanadores: _cantidadGanadores,
      );

      if (widget.sorteo == null) {
        await repo.crearSorteo(sorteo);
      } else {
        await repo.actualizarSorteo(sorteo.id, sorteo.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.sorteo == null
                ? 'Sorteo publicado 🎉'
                : 'Sorteo actualizado ✅'),
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
        title: Text(widget.sorteo == null ? 'Publicar sorteo' : 'Editar sorteo'),
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
              _campo('Título *', _tituloCtrl, 'Ej. Sorteo de invierno'),
              const SizedBox(height: 15),
              _campo('Descripción', _descCtrl, 'Opcional', maxLines: 2),
              const SizedBox(height: 15),
              _campo('Premio *', _premioCtrl, 'Ej. Canasta de productos'),
              const SizedBox(height: 15),

              // Fecha del sorteo
              const Text('Fecha del sorteo', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _fecha = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              // Cantidad de ganadores
              const SizedBox(height: 15),
              const Text('Cantidad de ganadores',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    onPressed: _cantidadGanadores > 1
                        ? () => setState(() => _cantidadGanadores--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_cantidadGanadores',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => setState(() => _cantidadGanadores++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Se elegirán al azar en la fecha del sorteo.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // URL de imagen (poster)
              _campo('URL de imagen (opcional)', _urlCtrl,
                  'Pegá el link del poster (Imgur, Cloudinary, etc.)'),
              const SizedBox(height: 8),
              const Text(
                'Sin Storage: pegás una URL externa. El campo queda listo para '
                'usar Firebase Storage cuando lo habilites.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 15),

              // Activo
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo (visible en la app)'),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v!),
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
                          widget.sorteo == null ? 'Publicar sorteo' : 'Guardar cambios',
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
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
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
          validator: (v) {
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
