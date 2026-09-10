import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/providers/cart_provider.dart';

/// Shell con barra de navegación inferior (Home / Promos / Carrito /
/// Mi cuenta). Envuelve las rutas principales de la tienda.
class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  int _indice(String loc) {
    if (loc.startsWith('/promos')) return 1;
    if (loc.startsWith('/cart')) return 2;
    if (loc.startsWith('/cuenta')) return 3;
    return 0; // home, category, search, sorteos, login -> Home
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.toString();
    final totalItems = ref
        .watch(cartProvider)
        .fold(0, (sum, item) => sum + item.cantidad);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice(loc),
        height: 68,
        elevation: 0,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.push('/promos');
            case 2:
              context.push('/cart');
            case 3:
              // Sin sesión: el perfil ES el login.
              if (ref.read(isLoggedInProvider)) {
                context.push('/cuenta');
              } else {
                context.push('/login');
              }
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer_rounded),
            label: 'Promos',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: totalItems > 0,
              label: Text('$totalItems'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: totalItems > 0,
              label: Text('$totalItems'),
              child: const Icon(Icons.shopping_cart_rounded),
            ),
            label: 'Carrito',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }
}
