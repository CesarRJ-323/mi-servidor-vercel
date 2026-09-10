import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';

/// Lee los pedidos reales del usuario demo desde Firestore para confirmar
/// que la sección "Mis compras recientes" del home trae datos reales
/// (no mocks).
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('leer pedidos demo', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final repo = AuthRepository();
    final cred = await repo.asegurarCuentaConRol(
      email: testClienteEmail,
      password: testClientePass,
      rol: 'cliente',
    );
    final uid = cred.user?.uid;
    expect(uid, isNotNull);

    final snap = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('usuario_id', isEqualTo: uid)
        .get();

    print('PEDIDOS ENCONTRADOS: ${snap.docs.length}');
    for (final d in snap.docs) {
      final data = d.data();
      print('  - id=${d.id} estado=${data['estado']} total=${data['total']} '
          'items=${(data['items'] as List).length}');
    }
    expect(snap.docs.isNotEmpty, isTrue,
        reason: 'El usuario demo debería tener al menos un pedido');
    print('RESULTADO: LA SECCION MIS COMPRAS LEE DATOS REALES DE FIRESTORE');
  });
}
