import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/promo_model.dart';
import 'package:delivery_app_v2/models/categoria_model.dart';

class AdminPromoScreen extends ConsumerStatefulWidget {
  final Promo? promo;
  const AdminPromoScreen({super.key, this.promo});

  @override
  ConsumerState<AdminPromoScreen> createState() => _AdminPromoScreenState();
}

class _AdminPromoScreenState extends ConsumerState<AdminPromoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();
  String _tipo = 'porcentaje';
  String _aplicarA = 'todos';
  String? _categoriaSel; // categoría específica cuando _aplicarA == 'categoria'
  bool _activa = true;

  @override
  void initState() {
    super.initState();
    if (widget.promo != null) {
      final p = widget.promo!;
      _nombreCtrl.text = p.nombre;
      _descCtrl.text = p.descripcion;
      _valorCtrl.text = p.valor.toString();
      _duracionCtrl.text = p.duracion;
      _tipo = p.tipo;
      _aplicarA = p.aplicarA.split(':').first;
      // Si aplicarA es 'categoria:xxx', extrae el id de la categoría
      if (_aplicarA == 'categoria' && p.aplicarA.contains(':')) {
        _categoriaSel = p.aplicarA.split(':')[1];
      }
      _activa = p.activa;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _valorCtrl.dispose();
    _duracionCtrl.dispose();
    super.dispose();
  }

  /// El campo "valor" es obligatorio SOLO para porcentaje y monto_fijo.
  /// Para 2x1 no tiene sentido (no hay porcentaje ni monto, es lleve 2 pague 1).
  bool get _valorEsObligatorio => _tipo == 'porcentaje' || _tipo == 'monto_fijo';

  /// El valor de aplicarA que se guarda en Firestore.
  /// 'todos' → 'todos', 'categoria' → 'categoria:xxx', 'producto' se eliminó.
  String get _aplicarAGuardar {
    if (_aplicarA == 'categoria' && _categoriaSel != null) {
      return 'categoria:$_categoriaSel';
    }
    return _aplicarA;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promo == null ? 'Nueva promoción' : 'Editar promoción'),
        backgroundColor: const Color(0xFF2A0800),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_nombreCtrl, 'Nombre *', '20% OFF Hamburguesas', required: true),
              const SizedBox(height: 16),
              _field(_descCtrl, 'Descripción', 'Válido todo el fin de semana'),
              const SizedBox(height: 16),

              // Tipo de promoción
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: _decoration('Tipo'),
                items: const [
                  DropdownMenuItem(value: 'porcentaje', child: Text('Porcentaje (%)')),
                  DropdownMenuItem(value: '2x1', child: Text('2x1')),
                  DropdownMenuItem(value: 'monto_fijo', child: Text('Monto fijo')),
                ],
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 16),

              // Valor — SOLO obligatorio para porcentaje y monto_fijo
              _field(
                _valorCtrl,
                _valorEsObligatorio ? 'Valor *' : 'Valor (opcional)',
                _valorEsObligatorio
                    ? (_tipo == 'monto_fijo' ? 'Ej. 500' : 'Ej. 20')
                    : 'No aplica para 2x1',
                required: _valorEsObligatorio,
                isNumeric: true,
                enabled: _valorEsObligatorio,
              ),
              const SizedBox(height: 16),

              // Aplicar a — SIN "producto específico" (redundante con descuentos directos)
              DropdownButtonFormField<String>(
                initialValue: _aplicarA,
                decoration: _decoration('Aplicar a'),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos los productos')),
                  DropdownMenuItem(value: 'categoria', child: Text('Categoría específica')),
                ],
                onChanged: _aplicarA == 'categoria' && _categoriaSel == null
                    ? (v) {
                        setState(() {
                          _aplicarA = v!;
                          if (v == 'categoria') {
                            _categoriaSel = categoriasCatalogo.first.id;
                          }
                        });
                      }
                    : (v) => setState(() => _aplicarA = v!),
              ),
              const SizedBox(height: 16),

              // Selector de categoría — SOLO visible cuando _aplicarA == 'categoria'
              if (_aplicarA == 'categoria')
                DropdownButtonFormField<String>(
                  initialValue: _categoriaSel ?? categoriasCatalogo.first.id,
                  decoration: _decoration('Seleccionar categoría'),
                  items: categoriasCatalogo
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.icon} ${c.nombre}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoriaSel = v),
                  validator: (v) {
                    if (_aplicarA == 'categoria' && (v == null || v.isEmpty)) {
                      return 'Seleccioná una categoría';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),

              _field(_duracionCtrl, 'Duración', 'Hoy 10:00 a 22:00'),
              const SizedBox(height: 16),

              SwitchListTile(
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
                title: const Text('Promoción activa'),
                activeThumbColor: const Color(0xFF0891B2),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Guardar promoción'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    String placeholder, {
    bool required = false,
    bool isNumeric = false,
    bool enabled = true,
  }) {
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
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: enabled ? const Color(0xFFFAFAFA) : Colors.grey[200],
          ),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null
              : null,
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(promoRepositoryProvider);

    final aplicarAGuardar = _aplicarAGuardar;

    final promo = Promo(
      id: widget.promo?.id ?? '',
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      tipo: _tipo,
      valor: double.tryParse(_valorCtrl.text) ?? 0,
      aplicarA: aplicarAGuardar,
      duracion: _duracionCtrl.text.trim(),
      activa: _activa,
      fechaCreacion: widget.promo?.fechaCreacion ?? DateTime.now(),
    );

    if (widget.promo == null) {
      await repo.crearPromo(promo);
    } else {
      await repo.actualizarPromo(promo.id, {
        'nombre': promo.nombre,
        'descripcion': promo.descripcion,
        'tipo': promo.tipo,
        'valor': promo.valor,
        'aplicar_a': promo.aplicarA,
        'duracion': promo.duracion,
        'activa': promo.activa,
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promoción guardada en Firebase')),
      );
      context.pop();
    }
  }
}
