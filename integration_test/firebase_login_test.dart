import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/main.dart' as app;

/// Firebase login + Firestore connectivity test.
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase login + Firestore connectivity', (tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Find the top-right "Iniciar sesión" button and tap it
    final loginButton = find.text('Iniciar sesión').last;
    await tester.tap(loginButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should be on login screen now
    expect(find.text('Bienvenido'), findsOneWidget);

    // Find email field by Key
    final emailField = find.byKey(const Key('emailField'));
    expect(emailField, findsOneWidget);
    await tester.tap(emailField);
    await tester.enterText(emailField, testAdminEmail);

    // Find password field by Key
    final passwordField = find.byKey(const Key('passwordField'));
    expect(passwordField, findsOneWidget);
    await tester.tap(passwordField);
    await tester.enterText(passwordField, testAdminPass);

    // Tap the login button
    final submitButton = find.text('Iniciar sesión');
    await tester.tap(submitButton.last);
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // After login, verify we're on the home or admin screen
    expect(find.byIcon(Icons.home), findsOneWidget);

    // Verify Firestore connectivity
    final firestore = FirebaseFirestore.instance;
    final promosSnapshot = await firestore.collection('promos').limit(1).get();
    assert(promosSnapshot.docs.isNotEmpty,
        'Firestore should return at least one promo (rules deployed)');

    final sorteosSnapshot = await firestore.collection('sorteos').limit(1).get();
    print('Firestore connected: promos=${promosSnapshot.docs.length}, sorteos=${sorteosSnapshot.docs.length}');

    // Verify auth state
    final auth = FirebaseAuth.instance;
    assert(auth.currentUser != null, 'Firebase Auth should be logged in');
    print('Firebase Auth: logged in as ${auth.currentUser?.email}');

    print('ALL TESTS PASSED: Firebase login + Firestore connectivity verified');
  });
}
