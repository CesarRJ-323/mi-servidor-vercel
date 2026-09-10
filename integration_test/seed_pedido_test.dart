import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';

/// Crea un pedido de prueba para el usuario demo, para verificar que la
/// sección "Mis compras recientes" del home lee datos reales de Firestore.
///
/// Correr con:
///   flutter test integration_test/seed_pedido_test.dart -d emulator-5554 \
///     --dart-define=TEST_CLIENTE_EMAIL=... --dart-define=TEST_CLIENTE_PASS=...
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed pedido demo', (tester) async {
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
    print('uid demo=$uid');

    // Crear un pedido de prueba vinculado a este usuario.
    // Incluye ambos campos para compatibilidad con la regla de Firestore
    // (usuario_id es el que usa la app; userId por si la regla del Console
    // aún usa la versión anterior).
    await FirebaseFirestore.instance.collection('pedidos').add({
      'usuario_id': uid,
      'userId': uid,
      'items': [
        {
          'producto_id': 'p1',
          'nombre_producto': 'Leche',
          'cantidad': 2,
          'precio_unitario': 1200,
        }
      ],
      'subtotal': 2400,
      'descuento_aplicado': 0,
      'tokens_utilizados': 0,
      'total': 2400,
      'direccion_envio': 'Calle 123',
      'estado': 'en_camino',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    print('OK: pedido de prueba creado para $uid');
  });
}
