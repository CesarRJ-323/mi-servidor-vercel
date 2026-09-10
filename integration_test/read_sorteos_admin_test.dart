import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';
import 'package:delivery_app_v2/data/repositories/sorteo_repository.dart';

/// Valida que el admin lee la lista de sorteos desde Firestore.
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin lee sorteos', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final repo = AuthRepository();
    await repo.asegurarCuentaConRol(
      email: testAdminEmail,
      password: testAdminPass,
      rol: 'admin',
    );

    final sorteoRepo = SorteoRepository();
    final lista = await sorteoRepo.streamTodosLosSorteos().first;
    print('SORTEOS EN ADMIN: ${lista.length}');
    for (final s in lista) {
      print('  - "${s.titulo}" activo=${s.activo} premio=${s.premio}');
    }
    expect(lista.isNotEmpty, isTrue);
    print('RESULTADO: LISTA DE SORTEOS DEL ADMIN LEE FIRESTORE');
  });
}
