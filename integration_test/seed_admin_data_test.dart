import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';
import 'package:delivery_app_v2/data/repositories/producto_repository.dart';
import 'package:delivery_app_v2/data/repositories/promo_repository.dart';
import 'package:delivery_app_v2/models/producto_model.dart';
import 'package:delivery_app_v2/models/promo_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin guarda producto y promo en Firebase', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final repo = AuthRepository();
    await repo.asegurarCuentaConRol(
      email: testAdminEmail,
      password: testAdminPass,
      rol: 'admin',
    );

    // Producto nuevo con categoría del catálogo compartido.
    final prodRepo = ProductoRepository();
    await prodRepo.crearProducto(Producto(
      id: '',
      nombre: 'Test Producto Firebase',
      precioBase: 199,
      categoria: 'bebidas',
      descripcion: 'Producto de prueba',
      urlImagen: '',
    ));
    final productos = await prodRepo.getProductos();
    final existeProd =
        productos.any((p) => p.nombre == 'Test Producto Firebase');
    print('PRODUCTO EN FIRESTORE: $existeProd (total=${productos.length})');

    // Promo nueva.
    final promoRepo = PromoRepository();
    await promoRepo.crearPromo(Promo(
      id: '',
      nombre: 'Test Promo Firebase',
      descripcion: 'Promo de prueba',
      tipo: 'porcentaje',
      valor: 15,
      aplicarA: 'todos',
      duracion: 'Hoy',
    ));
    final promosSnap = await promoRepo.streamTodasLasPromos().first;
    final existePromo =
        promosSnap.any((p) => p.nombre == 'Test Promo Firebase');
    print('PROMO EN FIRESTORE: $existePromo (total=${promosSnap.length})');

    expect(existeProd, isTrue);
    expect(existePromo, isTrue);
    print('RESULTADO: PRODUCTOS Y PROMOS SE GUARDAN Y LEEN DE FIRESTORE');
  });
}
