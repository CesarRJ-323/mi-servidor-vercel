import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app_v2/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo entra al panel admin', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Si abre en registro, ir a login.
    final enlaceLogin = find.text('¿Ya tenés cuenta? Iniciar sesión');
    if (tester.any(enlaceLogin)) {
      await tester.tap(enlaceLogin);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Llenar email y password usando EditableText (más directo).
    final edits = find.byType(EditableText);
    expect(edits.evaluate().length, greaterThanOrEqualTo(2),
        reason: 'no hay campos de texto');
    await tester.tap(edits.at(0));
    await tester.enterText(edits.at(0), testAdminEmail);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(edits.at(1));
    await tester.enterText(edits.at(1), testAdminPass);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final btn = find.text('Iniciar sesión');
    expect(tester.any(btn), isTrue);
    await tester.tap(btn);
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // ¿Estamos en el admin? Busca el header "Delivery Local" o "Resumen".
    final enAdmin = tester.any(find.text('Delivery Local')) ||
        tester.any(find.text('Resumen'));
    print('EN_ADMIN: $enAdmin');

    // ¿El nav tiene el icono de sorteos?
    final haySorteos = tester.any(find.byIcon(Icons.card_giftcard));
    print('HAY_NAV_SORTEOS: $haySorteos');

    expect(enAdmin, isTrue, reason: 'el demo no entro al panel admin');
    print('RESULTADO: DEMO ENTRA AL PANEL ADMIN');
  });
}
