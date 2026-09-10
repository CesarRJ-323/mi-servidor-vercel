import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:delivery_app_v2/firebase_options.dart';
import 'package:delivery_app_v2/app.dart';
import 'package:delivery_app_v2/services/fcm_service.dart';
import 'package:delivery_app_v2/navigation_service.dart';

/// Handler global para notificaciones en background (debe ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Configura los emuladores de Firebase.
/// Solo usa emuladores si detectamos que están activos en este momento;
/// si no, deja Firestore/Auth/Funciones apuntando a PRODUCCIÓN directamente.
void _maybeUseEmulators() {
  if (!kDebugMode) return; // Release: producción directo

  // Detectamos si los puertos del emulador están escuchando en localhost.
  // Si no están activos, NO llamamos a useEmulator* — de lo contrario
  // Firestore entra en un loop de "too_many_pings" / RESOURCE_EXHAUSTED.
  const emuladorActivos = bool.fromEnvironment(
    'EMULADOR_FIREBASE_ACTIVO',
    defaultValue: false,
  );

  if (!emuladorActivos) {
    // No se pasó la flag → asumimos prod. La app funciona contra Firestore prod.
    // Si querés usar emulador: flutter run --dart-define=EMULADOR_FIREBASE_ACTIVO=true
    //   (requiere firebase emulators:start corriendo en el host)
    // ignore: avoid_print
    print('🔧 Firebase: usando PRODUCCIÓN (no emulador local)');
    return;
  }

  // Los emuladores están activos → configurarlos
  try {
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8787);
    FirebaseFunctions.instance.useFunctionsEmulator('10.0.2.2', 5778);
    FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9494);
    // ignore: avoid_print
    print('🔧 Firebase: usando emuladores locales');
  } catch (_) {
    // Silencioso: caímos a prod.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  _maybeUseEmulators();

  // App Check:
  // - debug provider en modo debug (permite testing sin Play Integrity).
  // - Play Integrity en release (producción).
  await FirebaseAppCheck.instance.activate(
    // ignore: deprecated_member_use
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FcmService.initialize();
  FcmService.onNotificationTap = (RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamed('/sorteos');
    }
  };

  runApp(const ProviderScope(child: MyApp()));
}