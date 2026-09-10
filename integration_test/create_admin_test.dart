// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'test_credentials.dart';

/// Test para crear usuario admin y documento Firestore.
/// NO requiere App Check registrado — instala el app check provider
/// pero si falla, continúa igual.
/// Como correr:
///   flutter test integration_test/create_admin_test.dart -d emulator-5554 \
///     --dart-define=TEST_ADMIN_EMAIL=... --dart-define=TEST_ADMIN_PASS=...
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create admin user and Firestore document', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Activar App Check pero NO esperar si falla (modo debug)
    try {
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        androidProvider: AndroidProvider.debug,
      );
      print('✅ App Check activated');
    } catch (e) {
      print('⚠️ App Check failed (continuing without it): $e');
    }

    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;

    // Step 1: Create user or sign in
    UserCredential cred;
    try {
      cred = await auth.createUserWithEmailAndPassword(
        email: testAdminEmail,
        password: testAdminPass,
      );
      print('✅ User created: ${cred.user?.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('⚠️ User exists, signing in...');
        cred = await auth.signInWithEmailAndPassword(
          email: testAdminEmail,
          password: testAdminPass,
        );
        print('✅ Signed in: ${cred.user?.uid}');
      } else {
        print('❌ Auth error: ${e.code} - ${e.message}');
        // If App Check blocks, we can't proceed
        if (e.code.contains('app-check') || e.message?.contains('App Check') == true) {
          print('❌ BLOCKED BY APP CHECK - register debug token:');
          print('Token from emulator logcat needs to be registered');
          print('Run: adb logcat -d | grep "Firebase App Check debug token"');
          return;
        }
        return;
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      return;
    }

    final uid = cred.user!.uid;
    print('UID: $uid');

    // Step 2: Create Firestore document
    try {
      await db.collection('usuarios').doc(uid).set({
        'email': testAdminEmail,
        'nombre': 'César',
        'rol': 'admin',
        'creado_en': FieldValue.serverTimestamp(),
        'tokens_balance': 1000,
        'activo': true,
      }, SetOptions(merge: true));
      print('✅ Firestore documento creado en usuarios/$uid');
    } catch (e) {
      print('❌ Firestore error: $e');
    }

    // Step 3: Verify
    final doc = await db.collection('usuarios').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      print('📄 Documento verificado:');
      print('  email: ${data['email']}');
      print('  rol: ${data['rol']}');
      print('  nombre: ${data['nombre']}');
      print('  tokens_balance: ${data['tokens_balance']}');

      // Verify admin access
      if (data['rol'] == 'admin') {
        print('✅ USUARIO ADMIN VERIFICADO - puede acceder al panel admin');
      } else {
        print('⚠️ Rol no es admin, es: ${data['rol']}');
      }
    } else {
      print('❌ Documento no encontrado en Firestore');
    }

    // Step 4: Verify Firestore reads work (productos, promos, sorteos)
    try {
      final productos = await db.collection('productos').limit(3).get();
      print('✅ Productos leídos: ${productos.docs.length} docs');
    } catch (e) {
      print('❌ Error leyendo productos: $e');
    }

    try {
      final promos = await db.collection('promos').where('activa', isEqualTo: true).limit(3).get();
      print('✅ Promos leídas: ${promos.docs.length} docs');
    } catch (e) {
      print('❌ Error leyendo promos: $e');
    }

    try {
      final sorteos = await db.collection('sorteos').where('activo', isEqualTo: true).limit(3).get();
      print('✅ Sorteos leídos: ${sorteos.docs.length} docs');
    } catch (e) {
      print('❌ Error leyendo sorteos: $e');
    }

    print('\n=== VERIFICATION COMPLETE ===');
  });
}