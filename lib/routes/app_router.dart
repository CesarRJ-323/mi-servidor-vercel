import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_app_v2/providers/app_providers.dart';
import 'package:delivery_app_v2/providers/go_router_refresh_stream.dart';
import 'package:delivery_app_v2/screens/login_screen.dart';
import 'package:delivery_app_v2/widgets/home_shell.dart';
import 'package:delivery_app_v2/screens/sorteos_activos_screen.dart';
import 'package:delivery_app_v2/screens/home_screen.dart';
import 'package:delivery_app_v2/screens/cart_screen.dart';
import 'package:delivery_app_v2/screens/category_screen.dart';
import 'package:delivery_app_v2/screens/promos_screen.dart';
import 'package:delivery_app_v2/screens/admin/admin_dashboard.dart';
import 'package:delivery_app_v2/screens/admin/pedidos_screen.dart';
import 'package:delivery_app_v2/screens/admin/productos_screen.dart';
import 'package:delivery_app_v2/screens/admin/promos_screen.dart';
import 'package:delivery_app_v2/screens/admin/admin_producto_screen.dart';
import 'package:delivery_app_v2/screens/admin/admin_sorteo_screen.dart';
import 'package:delivery_app_v2/screens/admin/admin_sorteos_screen.dart';
import 'package:delivery_app_v2/screens/admin/admin_promo_screen.dart';
import 'package:delivery_app_v2/screens/admin/admin_descuentos_screen.dart';
import 'package:delivery_app_v2/screens/search_screen.dart';
import 'package:delivery_app_v2/screens/pago_resultado_screen.dart';
import 'package:delivery_app_v2/screens/cuenta_screen.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';
import 'package:delivery_app_v2/models/producto_model.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

import 'package:delivery_app_v2/navigation_service.dart';

/// Router con guards reales basados en Firebase Auth + rol del usuario.
GoRouter buildAppRouter(WidgetRef ref) {
  final authState = ref.watch(authStateProvider);
  final isLoggedIn = authState.value != null;
  final isAdmin = ref.watch(isAdminProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      // NORMALIZAR deep links de MercadoPago.
      // MP redirige a rapidiya://pago/exito?payment_id=xxx o rapidiya://pago/fallo?
      // GoRouter puede matchear el path como /exito (sin el /pago prefix) si el
      // intent-filter tiene pathPrefix="/". Normalizamos para redirigir a /pago/...
      final rawLocation = state.matchedLocation;
      // Usamos state.uri para capturar el scheme + host + path + query completo
      final uri = state.uri;

      String normalizedLocation;
      if (uri.host == 'pago') {
        // Deep link: rapidiya://pago/exito?payment_id=xxx
        // → normalizar a /pago/exito?payment_id=xxx
        final path = uri.path; // /exito, /fallo, /pendiente
        final query = uri.hasQuery ? '?${uri.query}' : '';
        normalizedLocation = '/pago$path$query';
      } else {
        normalizedLocation = rawLocation;
      }

      // Si el location incluía el scheme y lo normalizamos → redirect a la ruta.
      if (normalizedLocation != rawLocation) {
        return normalizedLocation;
      }

      // Login ya no es la pantalla inicial: la tienda es pública.
      // El login vive en /login y solo se exige cuando una acción lo pide.

      // Rutas que requieren autenticación explícita.
      // Si un usuario NO logueado intenta abrirlas directamente,
      // se lo redirige a /login para que haga click en "agregar al carrito".
      final rutasProtegidas = ['/cart', '/cuenta'];
      final protegida = rutasProtegidas.any(
        (r) => normalizedLocation == r || normalizedLocation.startsWith('$r/'),
      );
      if (protegida && !isLoggedIn) return '/login';

      // Logueado y cayó en /login -> al home (ya no necesita verlo).
      if (isLoggedIn && normalizedLocation == '/login') return '/home';

      // Logueado y en raíz -> al home.
      if (normalizedLocation == '/' && isLoggedIn) return '/home';

      // Rutas de admin protegidas por rol real.
      final esRutaAdmin = normalizedLocation.startsWith('/admin');
      if (esRutaAdmin && !isAdmin) return '/home';

      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return const HomeScreen();
            },
          ),
          GoRoute(
            path: '/sorteos',
            builder: (BuildContext context, GoRouterState state) {
              return const SorteosActivosScreen();
            },
          ),
          GoRoute(
            path: '/home',
            builder: (BuildContext context, GoRouterState state) {
              return const HomeScreen();
            },
          ),
          GoRoute(
            path: '/cart',
            builder: (BuildContext context, GoRouterState state) {
              return const CartScreen();
            },
          ),
          GoRoute(
            path: '/category/:id',
            builder: (BuildContext context, GoRouterState state) {
              final String categoryId = state.pathParameters['id']!;
              return CategoryScreen(categoryId: categoryId);
            },
          ),
          GoRoute(
            path: '/promos',
            builder: (BuildContext context, GoRouterState state) {
              return const PromosScreen();
            },
          ),
          GoRoute(
            path: '/search',
            builder: (BuildContext context, GoRouterState state) {
              return const SearchScreen();
            },
          ),
          GoRoute(
            path: '/cuenta',
            builder: (BuildContext context, GoRouterState state) {
              return const CuentaScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (BuildContext context, GoRouterState state) {
          return const AdminDashboardScreen();
        },
      ),
      GoRoute(
        path: '/admin/producto',
        builder: (BuildContext context, GoRouterState state) {
          // extra = Producto a editar (null = crear nuevo).
          final producto = state.extra as Producto?;
          return AdminProductoScreen(producto: producto);
        },
      ),
      GoRoute(
        path: '/admin/producto/:id',
        builder: (BuildContext context, GoRouterState state) {
          // La edición la resuelve la pantalla de lista; acá va siempre a crear.
          return const AdminProductoScreen();
        },
      ),
      GoRoute(
        path: '/admin/sorteo',
        builder: (BuildContext context, GoRouterState state) {
          final sorteo = state.extra as Sorteo?;
          return AdminSorteoScreen(sorteo: sorteo);
        },
      ),
      GoRoute(
        path: '/admin/sorteos',
        builder: (BuildContext context, GoRouterState state) {
          return const AdminSorteosScreen();
        },
      ),
      GoRoute(
        path: '/admin/pedidos',
        builder: (BuildContext context, GoRouterState state) {
          return const PedidosScreen();
        },
      ),
      GoRoute(
        path: '/admin/productos',
        builder: (BuildContext context, GoRouterState state) {
          return const ProductosScreen();
        },
      ),
      GoRoute(
        path: '/admin/promos',
        builder: (BuildContext context, GoRouterState state) {
          return const AdminPromosScreen();
        },
      ),
      GoRoute(
        path: '/admin/descuentos',
        builder: (BuildContext context, GoRouterState state) {
          return const AdminDescuentosScreen();
        },
      ),
      GoRoute(
        path: '/admin/promo',
        builder: (BuildContext context, GoRouterState state) {
          final promo = state.extra as Promo?;
          return AdminPromoScreen(promo: promo);
        },
      ),
      // ========================================
      // Deep links de Mercado Pago
      // ========================================
      GoRoute(
        path: '/pago/exito',
        builder: (BuildContext context, GoRouterState state) {
          // El deep link de MP puede traer query params: payment_id, etc.
          // Usamos state.queryParams para extraer el payment_id.
          final paymentId = state.uri.queryParameters['payment_id'];
          return PagoResultadoScreen(resultado: 'exito', paymentId: paymentId);
        },
      ),
      GoRoute(
        path: '/pago/fallo',
        builder: (BuildContext context, GoRouterState state) {
          return const PagoResultadoScreen(resultado: 'fallo');
        },
      ),
      GoRoute(
        path: '/pago/pendiente',
        builder: (BuildContext context, GoRouterState state) {
          return const PagoResultadoScreen(resultado: 'pendiente');
        },
      ),
    ],
  );
}
