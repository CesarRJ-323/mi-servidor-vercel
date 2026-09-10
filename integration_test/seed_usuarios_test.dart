import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';

/// Crea dos usuarios separados (admin + cliente) y verifica sus roles
/// haciendo login como cada uno antes de leer su propio doc.
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear cliente demo y admin demo', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final repo = AuthRepository();
    final db = FirebaseFirestore.instance;

    const adminEmail = testAdminEmail;
    const adminPass = testAdminPass;
    const cliEmail = testClienteEmail;
    const cliPass = testClientePass;

    // Crear (o asegurar) ambos.
    await repo.asegurarCuentaConRol(
        email: adminEmail, password: adminPass, rol: 'admin');
    await repo.asegurarCuentaConRol(
        email: cliEmail, password: cliPass, rol: 'cliente');

    // Verificar ADMIN: login como admin y leer su propio doc.
    await repo.iniciarSesion(adminEmail, adminPass);
    final adminUid = repo.currentUser!.uid;
    final aSnap = await db.collection('usuarios').doc(adminUid).get();
    final rolAdmin = aSnap.data()?['rol'];
    print('ADMIN rol=$rolAdmin uid=$adminUid');

    // Verificar CLIENTE: login como cliente y leer su propio doc.
    await repo.iniciarSesion(cliEmail, cliPass);
    final cliUid = repo.currentUser!.uid;
    final cSnap = await db.collection('usuarios').doc(cliUid).get();
    final rolCli = cSnap.data()?['rol'];
    print('CLIENTE rol=$rolCli uid=$cliUid');

    expect(rolAdmin, equals('admin'));
    expect(rolCli, equals('cliente'));

    print('RESULTADO: CLIENTE Y ADMIN DEMO CREADOS CON ROLES CORRECTOS');
  });
}
