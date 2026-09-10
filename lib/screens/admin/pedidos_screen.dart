import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/models/pedido_model.dart';

class PedidosScreen extends ConsumerWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(pedidosAdminStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        backgroundColor: const Color(0xFF2A0800),
      ),
      body: pedidosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Error al cargar pedidos.')),
        data: (pedidos) {
          if (pedidos.isEmpty) {
            return const Center(child: Text('No hay pedidos registrados.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            itemBuilder: (context, index) =>
                _buildPedidoCard(context, ref, pedidos[index]),
          );
        },
      ),
    );
  }

  Widget _buildPedidoCard(
      BuildContext context, WidgetRef ref, Pedido pedido) {
    final color = _colorEstado(pedido.estado);
    final detalle = pedido.items
        .map((i) => '${i.cantidad}x ${i.nombreProducto}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '#${pedido.id.length > 8 ? pedido.id.substring(0, 8) : pedido.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _textoEstado(pedido.estado),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _fila('Cliente', pedido.usuarioNombre.isNotEmpty
                ? pedido.usuarioNombre
                : pedido.usuarioId),
            if (pedido.usuarioWhatsapp.isNotEmpty)
              _fila('WhatsApp', pedido.usuarioWhatsapp)
            else if (pedido.usuarioTelefono.isNotEmpty)
              _fila('Teléfono', pedido.usuarioTelefono),
            _fila('Pidió', detalle.isNotEmpty ? detalle : '—'),
            _fila('Total', '\$${pedido.total.toStringAsFixed(0)}'),
            _fila('Dirección', pedido.direccionEnvio.isNotEmpty
                ? pedido.direccionEnvio
                : 'Sin dirección'),
            if (pedido.descripcionCasa.isNotEmpty)
              _fila('Casa', pedido.descripcionCasa),
            if (pedido.mapsUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: () async {
                    // Anti-phishing: solo https + hosts conocidos de Maps.
                    final uri = Uri.tryParse(pedido.mapsUrl);
                    const hostsOk = ['maps.google.com', 'maps.app.goo.gl',
                      'goo.gl', 'www.google.com', 'google.com'];
                    if (uri == null ||
                        uri.scheme != 'https' ||
                        !hostsOk.contains(uri.host.toLowerCase())) {
                      return;
                    }
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, size: 16, color: Color(0xFF0891B2)),
                      SizedBox(width: 4),
                      Text(
                        'Ver ubicación en Google Maps',
                        style: TextStyle(
                          color: Color(0xFF0891B2),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (pedido.direccionEnvio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: () {
                    final q = Uri.encodeComponent(pedido.direccionEnvio);
                    final url =
                        'https://www.google.com/maps/search/?api=1&query=$q';
                    // Se abre con url_launcher en una implementación completa.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Maps: $url')),
                    );
                  },
                  child: const Text(
                    'Ver en Google Maps',
                    style: TextStyle(
                      color: Color(0xFF0891B2),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => ref
                      .read(pedidoRepositoryProvider)
                      .actualizarEstado(
                        pedido.id,
                        _siguienteEstado(pedido.estado).name,
                      ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                      'Avanzar a ${_textoEstado(_siguienteEstado(pedido.estado))}'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    // Cancelar = BORRAR el pedido de Firebase
                    // (los cancelados no aportan historial).
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Cancelar pedido?'),
                        content: Text(
                            'El pedido de \${pedido.nombreCliente} se '
                            'eliminará permanentemente.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sí, cancelar y borrar',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref
                        .read(pedidoRepositoryProvider)
                        .eliminarPedido(pedido.id);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF775144)),
            ),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(color: Color(0xFF775144))),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoPedido e) {
    switch (e) {
      case EstadoPedido.pendiente:
        return Colors.blue;
      case EstadoPedido.confirmado:
        return Colors.indigo;
      case EstadoPedido.enCamino:
        return Colors.orange;
      case EstadoPedido.entregado:
        return Colors.green;
      case EstadoPedido.cancelado:
        return Colors.red;
    }
  }

  String _textoEstado(EstadoPedido e) {
    return e.toString().split('.').last.replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => ' ${m.group(0)}',
        );
  }

  EstadoPedido _siguienteEstado(EstadoPedido e) {
    switch (e) {
      case EstadoPedido.pendiente:
        return EstadoPedido.confirmado;
      case EstadoPedido.confirmado:
        return EstadoPedido.enCamino;
      case EstadoPedido.enCamino:
        return EstadoPedido.entregado;
      case EstadoPedido.entregado:
      case EstadoPedido.cancelado:
        return e;
    }
  }
}
