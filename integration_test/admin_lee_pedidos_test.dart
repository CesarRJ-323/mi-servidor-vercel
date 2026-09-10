import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';
import 'package:delivery_app_v2/data/repositories/pedido_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin lee TODOS los pedidos (panel admin)', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final repo = AuthRepository();
    // Login como admin (rol admin en Firestore).
    await repo.asegurarCuentaConRol(
      email: testAdminEmail,
      password: testAdminPass,
      rol: 'admin',
    );

    // Esto es EXACTAMENTE lo que hace el panel admin: streamTodosLosPedidos().
    final pedidoRepo = PedidoRepository();
    final pedidos = await pedidoRepo.streamTodosLosPedidos().first;

    print('PEDIDOS LEIDOS POR ADMIN: ${pedidos.length}');
    print('RESULTADO: EL PANEL ADMIN YA PUEDE LEER TODOS LOS PEDIDOS');
    expect(pedidos, isA<List>());
  });
}
