import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/models/usuario_model.dart';

/// Modal para editar la dirección de entrega del usuario.
/// - Dirección: obligatoria.
/// - Link de Google Maps: opcional.
/// - Pide confirmación antes de guardar.
/// Devuelve true si se guardó (para que el caller refresque).
Future<bool> mostrarModalDireccion(
  BuildContext context, {
  required Usuario usuario,
  required Future<void> Function(String direccion, String mapsUrl,
          String descripcionCasa)
      onGuardar,
}) async {
  final direccionCtrl = TextEditingController(text: usuario.direccion);
  final mapsCtrl = TextEditingController(text: usuario.mapsUrl);
  final casaCtrl = TextEditingController(text: usuario.descripcionCasa);
  final formKey = GlobalKey<FormState>();
  bool guardando = false;

  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> guardar() async {
            // Validación de campos del formulario.
            if (!formKey.currentState!.validate()) return;

            // Paso de confirmación explícito.
            final confirmar = await showDialog<bool>(
              context: ctx,
              builder: (dctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                title: const Text('¿Guardar cambios?'),
                content: Text(
                  'Tu dirección de entrega será:\n\n'
                  '📍 ${direccionCtrl.text.trim()}\n\n'
                  '🏠 Pista: ${casaCtrl.text.trim().isEmpty ? "(sin pista)" : casaCtrl.text.trim()}\n\n'
                  '${mapsCtrl.text.trim().isNotEmpty ? "Con link de Google Maps adjuntado." : "Sin link de Google Maps."}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dctx, true),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            );

            if (confirmar != true) return;

            setModalState(() => guardando = true);
            try {
              await onGuardar(
                direccionCtrl.text.trim(),
                mapsCtrl.text.trim(),
                casaCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (_) {
              setModalState(() => guardando = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo guardar. Intentá de nuevo.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Asa del modal
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.outline,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dirección de entrega',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dirección (obligatoria)
                    const Text(
                      'Dirección *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: direccionCtrl,
                      maxLength: 200,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Ingresá tu dirección'
                              : null,
                      decoration: InputDecoration(
                        hintText: 'Calle 123, Ciudad',
                        prefixIcon: const Icon(Icons.location_on_rounded,
                            size: 20, color: AppColors.textMuted),
                        hintStyle:
                            const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Link de Google Maps (opcional)
                    const Text(
                      'Link de Google Maps (opcional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: mapsCtrl,
                      maxLength: 2048,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'https://maps.app.goo.gl/...',
                        prefixIcon: const Icon(Icons.map_rounded,
                            size: 20, color: AppColors.textMuted),
                        hintStyle:
                            const TextStyle(color: AppColors.textMuted),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        // Opcional: vacío está bien. Si viene algo, que
                        // al menos parezca URL.
                        if (t.isNotEmpty && !t.startsWith('https://')) {
                          return 'El link debe ser una URL https de Google Maps';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pista para el delivery (obligatoria)
                    const Text(
                      '¿Cómo es tu casa? (pista para el delivery) *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: casaCtrl,
                      maxLength: 300,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Contale al delivery cómo llegar (ej: portón negro, 2º piso)'
                              : null,
                      decoration: InputDecoration(
                        hintText:
                            'Ej: portón negro, 2º piso, timbre 5...',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 30),
                          child: Icon(Icons.home_rounded,
                              size: 20, color: AppColors.textMuted),
                        ),
                        hintStyle:
                            const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                guardando ? null : () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: AppColors.outline),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.button),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: guardando ? null : guardar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.button),
                              ),
                            ),
                            child: guardando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text(
                                    'Guardar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  return resultado ?? false;
}
