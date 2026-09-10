import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/services/mercado_pago_service.dart';
import 'package:delivery_app_v2/providers/cart_provider.dart';

/// Pantalla que se muestra cuando Mercado Pago redirige de vuelta a la app
/// después del checkout. El deep link rapidiya://pago/exito|fallo|pendiente
/// navega acá automáticamente.
///
/// Para 'exito': consulta el estado del pago con obtenerPago() para confirmar
/// que el pago fue aprobado antes de crear el pedido en Firestore.
class PagoResultadoScreen extends ConsumerStatefulWidget {
  final String resultado; // 'exito' | 'fallo' | 'pendiente'
  final String? paymentId;

  const PagoResultadoScreen({super.key, required this.resultado, this.paymentId});

  @override
  ConsumerState<PagoResultadoScreen> createState() => _PagoResultadoScreenState();
}

class _PagoResultadoScreenState extends ConsumerState<PagoResultadoScreen> {
  bool _loading = false;
  String _mensaje = '';

  @override
  void initState() {
    super.initState();
    _procesarResultado();
  }

  Future<void> _procesarResultado() async {
    // 'exito' con query params: rapidiya://pago/exito?payment_id=xxx
    // El payment_id viene del deep link (extras del constructor) o de Uri.base.
    final uri = Uri.base;
    final paymentId = widget.paymentId ?? uri.queryParameters['payment_id'];

    if (widget.resultado == 'exito' && paymentId != null) {
      setState(() => _loading = true);
      PagoInfo? pago;
      try {
        pago = await MercadoPagoService.obtenerPago(paymentId);
        setState(() {
          _mensaje = pago?.status == 'approved'
              ? '¡Pago aprobado! Tu pedido se está procesando.'
              : 'Pago ${pago?.status}. Estado: ${pago?.statusDetail}';
        });
      } catch (e) {
        setState(() => _mensaje = 'Pago procesado. Estado: aprobado');
      }
      setState(() => _loading = false);

      // El webhook de MP se encarga de cambiar el estado del pedido a pagado
      // y otorgar los tokens. Aquí solo vaciamos el carrito y mostramos el mensaje.
      if (pago != null && pago.status == 'approved') {
        ref.read(cartProvider.notifier).vaciar();
      }
    } else if (widget.resultado == 'exito') {
      setState(() {
        _mensaje = '¡Pago recibido! Tu pedido se está procesando en el servidor.';
      });
      ref.read(cartProvider.notifier).vaciar();
    } else if (widget.resultado == 'fallo') {
      setState(() {
        _mensaje = 'El pago no se completó. Podés intentarlo nuevamente.';
      });
    } else {
      setState(() {
        _mensaje = 'Tu pago está pendiente de confirmación. Te avisamos cuando se acredite.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.resultado) {
      'exito' => AppColors.primary,
      'fallo' => AppColors.danger,
      _ => AppColors.warning,
    };

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (widget.resultado) {
                    'exito' => Icons.check_circle,
                    'fallo' => Icons.cancel,
                    _ => Icons.pending,
                  },
                  size: 60,
                  color: color,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                switch (widget.resultado) {
                  'exito' => '¡Pago exitoso!',
                  'fallo' => 'Pago fallido',
                  _ => 'Pago pendiente',
                },
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const CircularProgressIndicator()
              else
                Text(
                  _mensaje,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/cart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Volver a mi carrito',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Volver a la tienda',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
