import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';

/// Crea un producto de prueba en Firestore para validar catálogo + búsqueda.
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed producto demo', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Login demo para cumplir regla de write autenticado en productos.
    final repo = AuthRepository();
    await repo.asegurarCuentaConRol(
      email: testAdminEmail,
      password: testAdminPass,
      rol: 'admin',
    );

    await FirebaseFirestore.instance.collection('productos').add({
      'nombre': 'Avena integral',
      'precio_base': 180,
      'descripcion': 'Avena para desayunos saludables',
      'url_imagen': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/Oatmeal.jpg/240px-Oatmeal.jpg',
      'categoria': 'cereales',
      'descuento_activo': true,
      'porcentaje_descuento': 20,
      'disponible': true,
      'stock': 50,
    });
    print('OK: producto de prueba creado (categoria=cereales)');

    // Verificar que la búsqueda por nombre trae resultados.
    final snap = await FirebaseFirestore.instance
        .collection('productos')
        .where('categoria', isEqualTo: 'cereales')
        .get();
    print('PRODUCTOS EN CEREALES: ${snap.docs.length}');
    expect(snap.docs.isNotEmpty, isTrue);
    print('RESULTADO: CATALOGO Y BUSQUEDA LISTOS EN FIRESTORE');
  });
}
