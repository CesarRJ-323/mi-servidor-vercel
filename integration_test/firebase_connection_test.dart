import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';

/// Crea (o loguea) el usuario demo directamente en Firebase y verifica la
/// conexión de Auth + Firestore. No es UI: es para sembrar la cuenta de prueba.
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear usuario demo en firebase', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final repo = AuthRepository();
    final cred = await repo.asegurarCuentaConRol(
      email: testAdminEmail,
      password: testAdminPass,
      rol: 'admin',
    );
    final uid = cred.user?.uid;
    expect(uid, isNotNull, reason: 'No se obtuvo uid');
    print('OK: usuario demo auth uid=$uid');

    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();
    expect(snap.exists, isTrue, reason: 'No existe el doc usuarios/$uid');
    print('OK: Firestore usuarios/$uid rol=${snap.data()?['rol']}');

    print('RESULTADO: USUARIO DEMO LISTO -> email=$testAdminEmail');
  });
}
