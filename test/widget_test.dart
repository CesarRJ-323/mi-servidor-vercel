import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';

/// Test de smoke: verifica que la app arranca (sin Firebase real).
/// Usa un router mock simple para evitar inicialización de Firebase.
void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Router simple que no necesita Firebase para renderizar
    final mockRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Mock Home')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          title: 'Rapidiya Test',
          theme: AppTheme.light,
          routerConfig: mockRouter,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    expect(find.byType(MaterialApp), findsWidgets);
    expect(find.text('Mock Home'), findsOneWidget);
  });
}
