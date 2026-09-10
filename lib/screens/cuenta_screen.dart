import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';

/// Pantalla "Mi cuenta": datos del usuario logueado + edición de
/// dirección + cerrar sesión. Si es invitado, empuja al login.
class CuentaScreen extends ConsumerWidget {
  const CuentaScreen({super.key});

  /// Solo abre links https de hosts conocidos de Maps (anti-phishing).
  bool _esUrlMapsSegura(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    const hostsPermitidos = [
      'maps.google.com',
      'maps.app.goo.gl',
      'goo.gl',
      'www.google.com',
      'google.com',
    ];
    return hostsPermitidos.contains(uri.host.toLowerCase());
  }

  Future<void> _abrirMaps(String url) async {
    if (!_esUrlMapsSegura(url)) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(usuarioActualProvider);
    final usuario = usuarioAsync.valueOrNull;

    // Invitado: ni debería llegar acá (el shell manda al login),
    // pero por defensa: login.
    if (usuario == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.push('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final inicial = usuario.nombre.isNotEmpty
        ? usuario.nombre
            .trim()
            .split(RegExp(r'\\s+'))
            .where((p) => p.isNotEmpty)
            .map((p) => p[0].toUpperCase())
            .take(2)
            .join()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mi cuenta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Avatar con iniciales
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              usuario.nombre,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              usuario.email,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Tarjeta de datos
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.card),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  _filaDatos(
                    icon: Icons.phone_rounded,
                    label: 'WhatsApp',
                    valor: usuario.telefono.isNotEmpty ? usuario.telefono : '—',
                  ),
                  const Divider(height: 24, color: AppColors.outline),
                  _filaDatos(
                    icon: Icons.location_on_rounded,
                    label: 'Dirección',
                    valor: usuario.direccion.isNotEmpty
                        ? usuario.direccion
                        : 'Sin dirección',
                  ),
                  if (usuario.mapsUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => _abrirMaps(usuario.mapsUrl),
                        child: const Text(
                          '🗺 Abrir en Google Maps',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 24, color: AppColors.outline),
                  _filaDatos(
                    icon: Icons.home_rounded,
                    label: 'Pista para el delivery',
                    valor: usuario.descripcionCasa.isNotEmpty
                        ? usuario.descripcionCasa
                        : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tokens and Tickets balances
            Builder(
              builder: (context) {
                final tokenAsync = ref.watch(tokenBalanceStreamProvider);
                final ticketAsync = ref.watch(ticketBalanceStreamProvider);
                return Column(
                  children: [
                    tokenAsync.when(
                      data: (tokens) => ListTile(
                        leading: const Icon(Icons.monetization_on, color: Colors.amber),
                        title: const Text('Tokens'),
                        trailing: Text(
                          '$tokens',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      loading: () => const ListTile(
                        leading: Icon(Icons.monetization_on),
                        title: Text('Tokens'),
                        trailing: CircularProgressIndicator(),
                      ),
                      error: (e, _) => ListTile(
                        leading: const Icon(Icons.error),
                        title: const Text('Tokens'),
                        trailing: Text('Error', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ticketAsync.when(
                      data: (tickets) => ListTile(
                        leading: const Icon(Icons.confirmation_number, color: Colors.green),
                        title: const Text('Tickets'),
                        trailing: Text(
                          '$tickets',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      loading: () => const ListTile(
                        leading: Icon(Icons.confirmation_number),
                        title: Text('Tickets'),
                        trailing: CircularProgressIndicator(),
                      ),
                      error: (e, _) => ListTile(
                        leading: const Icon(Icons.error),
                        title: const Text('Tickets'),
                        trailing: Text('Error', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Buy ticket button
            ElevatedButton(
              onPressed: () async {
                final service = ref.read(ticketServiceProvider);
                final success = await service.comprarTicketConTokens();
                if (!context.mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket comprado exitosamente')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No tenés suficientes tokens')),
                  );
                }
              },
              child: const Text('Comprar 1 ticket (5 tokens)'),
            ),

            const SizedBox(height: 12),

            // Cerrar sesión
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).cerrarSesion();
                  if (context.mounted) context.go('/home');
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDatos({
    required IconData icon,
    required String label,
    required String valor,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}