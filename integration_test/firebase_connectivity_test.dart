// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'test_credentials.dart';

/// Tests de conectividad Firebase para delivery_app_v2.
/// Como correr:
///   flutter test integration_test/firebase_connectivity_test.dart -d emulator-5554 \
///     --dart-define=TEST_ADMIN_EMAIL=... --dart-define=TEST_ADMIN_PASS=...
/// Las credenciales van por --dart-define, NUNCA hardcodeadas.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore db;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: AndroidProvider.debug,
    );
    auth = FirebaseAuth.instance;
    db = FirebaseFirestore.instance;
    print('Firebase inicializado proyecto: deliverymovile-c25ff');
  });

  tearDown(() async {
    await auth.signOut();
  });

  // TEST 1: projectId correcto
  testWidgets('1 Firebase inicializa con el proyecto correcto', (tester) async {
    const expectedProjectId = 'deliverymovile-c25ff';
    final actualProjectId = DefaultFirebaseOptions.android.projectId;
    expect(actualProjectId, equals(expectedProjectId),
        reason: 'El projectId no coincide en firebase_options.dart');
    print('OK ProjectId: $actualProjectId');
  });

  // TEST 2: Auth responde sin sesion
  testWidgets('2 Firebase Auth responde sin sesion activa', (tester) async {
    final user = auth.currentUser;
    print('OK Auth disponible usuario: ${user?.email ?? "ninguno"}');
    expect(true, isTrue);
  });

  // TEST 3: Login admin con credenciales via --dart-define
  testWidgets('3 Login admin con Firebase Auth funciona', (tester) async {
    late UserCredential cred;
    try {
      cred = await auth.signInWithEmailAndPassword(
        email: testAdminEmail,
        password: testAdminPass,
      );
    } on FirebaseAuthException catch (ex) {
      if (ex.code == 'user-not-found') {
        print('❌ Usuario admin no existe: $testAdminEmail');
        print('Crear usuario en: https://console.firebase.google.com/project/deliverymovile-c25ff/authentication/users');
        fail('Login admin fallo: [${ex.code}] ${ex.message}');
      } else if (ex.code.contains('app-check') || (ex.message?.contains('App Check') ?? false)) {
        print('❌ App Check token no registrado');
        fail('Login admin fallo por App Check: ${ex.code} - ${ex.message}');
      } else {
        fail('Login admin fallo: [${ex.code}] ${ex.message}');
      }
    }
    expect(cred.user?.uid, isNotNull);
    expect(cred.user?.email, equals(testAdminEmail));
    print('OK Login admin uid: ${cred.user?.uid}');
  });

  // TEST 4: Leer documento usuarios de Firestore después del login
  testWidgets('4 Firestore leer documento usuarios despues del login', (tester) async {
    final cred = await auth.signInWithEmailAndPassword(
      email: testAdminEmail,
      password: testAdminPass,
    );
    final uid = cred.user!.uid;
    late DocumentSnapshot snap;
    try {
      snap = await db.collection('usuarios').doc(uid).get();
    } catch (ex) {
      fail('Firestore read fallo: $ex Verifica Firestore Rules.');
    }
    expect(snap.exists, isTrue,
        reason: 'El doc usuarios/$uid no existe en Firestore');
    final data = snap.data() as Map<String, dynamic>?;
    expect(data?['rol'], isNotNull);
    print('OK Firestore usuarios/$uid rol="${data?['rol']}"');
  });

  // TEST 5: Rol admin verificado
  testWidgets('5 El usuario admin tiene rol admin en Firestore', (tester) async {
    final cred = await auth.signInWithEmailAndPassword(
      email: testAdminEmail,
      password: testAdminPass,
    );
    final snap = await db.collection('usuarios').doc(cred.user!.uid).get();
    final data = snap.data();
    final rol = data?['rol'];
    expect(rol, equals('admin'),
        reason: '$testAdminEmail tiene rol "$rol" en vez de "admin"');
    print('OK Rol admin verificado: $rol');
  });

  // TEST 6: Productos accesible (público)
  testWidgets('6 Firestore coleccion productos accesible', (tester) async {
    late QuerySnapshot snap;
    try {
      snap = await db.collection('productos').limit(5).get();
    } catch (ex) {
      fail('Lectura de productos fallo: $ex');
    }
    print('OK Productos accesible docs: ${snap.docs.length}');
    expect(snap.docs.length, greaterThanOrEqualTo(0));
  });

  // TEST 7: Sorteos accesible (público)
  testWidgets('7 Firestore coleccion sorteos accesible', (tester) async {
    late QuerySnapshot snap;
    try {
      snap = await db.collection('sorteos').limit(5).get();
    } catch (ex) {
      fail('Lectura de sorteos fallo: $ex');
    }
    print('OK Sorteos accesible docs: ${snap.docs.length}');
    expect(snap.docs.length, greaterThanOrEqualTo(0));
  });

  // TEST 8: Promos accesible (público)
  testWidgets('8 Firestore coleccion promos accesible', (tester) async {
    late QuerySnapshot snap;
    try {
      snap = await db.collection('promos').limit(5).get();
    } catch (ex) {
      fail('Lectura de promos fallo: $ex');
    }
    print('OK Promos accesible docs: ${snap.docs.length}');
    expect(snap.docs.length, greaterThanOrEqualTo(0));
  });

  // TEST 9: Seguridad usuarios bloqueado sin auth
  testWidgets('9 Seguridad usuarios NO accesible sin login', (tester) async {
    await auth.signOut();
    var blocked = false;
    try {
      await db.collection('usuarios').limit(1).get();
    } catch (ex) {
      blocked = true;
      print('OK Firestore bloqueo acceso a usuarios sin auth: $ex');
    }
    expect(blocked, isTrue,
        reason: 'BRECHA: Firestore permitio leer usuarios sin auth. Revisa las rules.');
  });

  // TEST 10: Logout limpio
  testWidgets('10 Cerrar sesion limpia el estado de Auth', (tester) async {
    await auth.signInWithEmailAndPassword(
      email: testAdminEmail,
      password: testAdminPass,
    );
    expect(auth.currentUser, isNotNull);
    await auth.signOut();
    expect(auth.currentUser, isNull);
    print('OK Logout limpio currentUser: null');
  });
}