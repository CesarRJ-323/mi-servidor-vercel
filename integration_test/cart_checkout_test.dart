import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery_app_v2/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Checkout abre Chrome con init_point de MP', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Buscar boton login en header
    final loginFinder = find.text('Iniciar sesión');
    if (loginFinder.evaluate().isNotEmpty) {
      await tester.tap(loginFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    // Escribir email
    await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // ... etc
  });
}
