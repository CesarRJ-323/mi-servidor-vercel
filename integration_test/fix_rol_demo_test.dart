import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';

/// Fuerza el doc del usuario demo a rol 'admin' y verifica que se lee así.
/// Credenciales vía --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fijar rol admin demo', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final email = testAdminEmail;
    final password = testAdminPass;
    final repo = AuthRepository();
    final cred = await repo.asegurarCuentaConRol(email: email, password: password, rol: 'admin');
    final uid = cred.user!.uid;

    // Forzar rol admin en el doc (por si quedó como cliente de antes).
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
      {
        'uid': uid,
        'nombre': 'Demo Admin',
        'email': email,
        'telefono': '',
        'direccion': '',
        'tokens_balance': 0,
        'rol': 'admin',
        'creado_en': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Leer y confirmar.
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();
    final rol = snap.data()?['rol'];
    print('ROL DEL DEMO: $rol');
    expect(rol, equals('admin'));

    print('RESULTADO: DEMO TIENE ROL ADMIN EN FIRESTORE');
  });
}
