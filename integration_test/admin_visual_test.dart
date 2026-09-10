import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app_v2/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login -> admin -> nav sorteos muestra lista de Firestore', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Si abre en registro, ir a login.
    final enlaceLogin = find.text('¿Ya tenés cuenta? Iniciar sesión');
    if (tester.any(enlaceLogin)) {
      await tester.tap(enlaceLogin);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Llenar email y password.
    final fields = find.byType(TextField);
    await tester.tap(fields.at(0));
    await tester.enterText(fields.at(0), testAdminEmail);
    await tester.pumpAndSettle();
    await tester.tap(fields.at(1));
    await tester.enterText(fields.at(1), testAdminPass);
    await tester.pumpAndSettle();

    final btn = find.text('Iniciar sesión');
    expect(tester.any(btn), isTrue, reason: 'no encontro boton Iniciar sesion');
    await tester.tap(btn);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ¿Estamos en el admin? Buscamos texto del dashboard.
    final enAdmin = tester.any(find.text('Delivery Local')) || tester.any(find.text('Resumen'));
    print('EN_ADMIN: $enAdmin');

    // Ir al nav Sorteos.
    final sorteosIcon = find.byIcon(Icons.card_giftcard);
    expect(sorteosIcon.evaluate().length, greaterThanOrEqualTo(1),
        reason: 'no hay icono de sorteos en el nav');
    await tester.tap(sorteosIcon.last);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ¿Aparece el sorteo de Firestore en la lista?
    final veSorteo = tester.any(find.text('Sorteo de invierno'));
    print('VE_SORTEO_EN_ADMIN: $veSorteo');
    expect(veSorteo, isTrue, reason: 'el sorteo de Firestore no aparece en la lista del admin');

    print('RESULTADO: ADMIN NAVEGA A SORTEOS Y MUESTRA LISTA DE FIRESTORE');
  });
}
