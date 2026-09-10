import 'test_credentials.dart';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/data/repositories/auth_repository.dart';
import 'package:delivery_app_v2/data/repositories/sorteo_repository.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';

/// Crea un sorteo de prueba y valida que se lee como activo.
/// Credenciales via --dart-define (ver test_credentials.dart).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed sorteo demo', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final repo = AuthRepository();
    await repo.asegurarCuentaConRol(
      email: testAdminEmail,
      password: testAdminPass,
      rol: 'admin',
    );

    // Crear sorteo de prueba.
    final sorteoRepo = SorteoRepository();
    await sorteoRepo.crearSorteo(Sorteo(
      id: '',
      titulo: 'Sorteo de invierno',
      descripcion: 'Participá por una canasta de productos',
      premio: 'Canasta de productos',
      fechaSorteo: DateTime.now().add(const Duration(days: 5)),
      imagenUrl: '',
      activo: true,
      creadoEn: DateTime.now(),
    ));
    print('OK: sorteo de prueba creado');

    // Verificar que se lee como activo.
    final snap = await FirebaseFirestore.instance
        .collection('sorteos')
        .where('activo', isEqualTo: true)
        .get();
    print('SORTEOS ACTIVOS: ${snap.docs.length}');
    expect(snap.docs.isNotEmpty, isTrue);

    print('RESULTADO: SORTEOS LISTOS EN FIRESTORE');
  });
}
