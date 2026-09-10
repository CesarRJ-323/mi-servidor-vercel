import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:delivery_app_v2/services/rate_limiter_service.dart';
import 'package:delivery_app_v2/services/server_rate_limiter_service.dart';
import 'package:delivery_app_v2/services/fcm_service.dart';

/// Envuelve Firebase Auth. Expone los métodos que usa la UI.
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final RateLimiterService _rateLimiter;
  final FirebaseFunctions _functions;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    RateLimiterService? rateLimiter,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _rateLimiter = rateLimiter ?? RateLimiterService(),
        _functions = functions ?? FirebaseFunctions.instance;

  // Stream de estado de sesión: null = no logueado.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> iniciarSesion(String email, String password) async {
    final identificador = email.trim().toLowerCase();

    // 1. Rate limiting LOCAL (best-effort): max 5 intentos por 60s
    final restanteLocal = _rateLimiter.puedeEjecutar('login', identificador);
    if (restanteLocal != null) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Demasiados intentos. ${restanteLocal.aTextoAmigable()}',
      );
    }

    // 2. Rate limiting SERVER-SIDE (real): valida contra Firestore.
    // En debug, si la función falla por emulador/AppCheck, HACEMOS FAIL-OPEN
    // para permitir login en dev. En prod, propagamos el error.
    if (!kDebugMode) {
      final serverCheck = await ServerRateLimiter.check(
        functions: _functions,
        accion: 'login_attempts',
        identificador: identificador,
      );
      if (!serverCheck['allowed']) {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: serverCheck['message'] ??
              'Demasiados intentos. Intentálo más tarde.',
        );
      }
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        FcmService.guardarTokenParaUsuario(cred.user!.uid);
      }
      return cred;
    } catch (e, st) {
      debugPrint('[AuthRepository.iniciarSesion] Error real: $e\nST: $st');
      rethrow;
    }
  }

  /// Crea el usuario en Auth y su documento en `usuarios/{uid}` con rol 'cliente'.
  Future<UserCredential> registrar({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
    required String direccion,
    String mapsUrl = '',
    required String descripcionCasa,
  }) async {
    final identificador = email.trim().toLowerCase();

    // 1. Rate limiting LOCAL: max 3 registros por 60s
    final restanteLocal = _rateLimiter.puedeEjecutar('registro', identificador);
    if (restanteLocal != null) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Demasiados registros. ${restanteLocal.aTextoAmigable()}',
      );
    }

    // 2. Rate limiting SERVER-SIDE: valida contra Firestore
    final serverCheck = await ServerRateLimiter.check(
      functions: _functions,
      accion: 'account_creation',
      identificador: identificador,
    );

    if (!serverCheck['allowed']) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: serverCheck['message'] ??
            'Demasiados registros. Intentálo más tarde.',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) throw Exception('No se pudo obtener el uid del usuario');

    await _db.collection('usuarios').doc(uid).set({
      'uid': uid,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'maps_url': mapsUrl,
      'descripcion_casa': descripcionCasa,
      'tokens_balance': 0,
      'rol': 'cliente',
      'creado_en': FieldValue.serverTimestamp(),
    });
    // Guardar token FCM después del registro exitoso
    await FcmService.guardarTokenParaUsuario(uid);
    return cred;
  }

  Future<void> cerrarSesion() async {
    await FcmService.desuscribir();
    await _auth.signOut();
  }


  /// Envía el email de restablecimiento de contraseña.
  Future<void> recuperarContrasena(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Crea (o inicia sesión si ya existe) una cuenta demo con rol 'admin'.
  /// El email debe ser @gmail.com para cumplir la validación de dominio.
  /// Sirve para verificar de punta a punta que Firebase Auth + Firestore
  /// están conectados: si esto crea el usuario, la conexión funciona.
  Future<UserCredential> asegurarCuentaDemo({
    required String email,
    required String password,
  }) async {
    // SEGURIDAD: crear admins desde el cliente es algo de desarrollo.
    // En release esto queda bloqueado.
    if (!kDebugMode) {
      throw StateError('asegurarCuentaDemo solo está disponible en debug.');
    }
    try {
      // ¿Ya existe? -> login directo.
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // No existe -> la creamos con rol admin en Firestore.
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user?.uid;
        if (uid == null) {
          throw Exception('No se pudo obtener el uid del usuario demo');
        }
        await _db.collection('usuarios').doc(uid).set({
          'uid': uid,
          'nombre': 'Demo Admin',
          'email': email,
          'telefono': '',
          'direccion': '',
          'tokens_balance': 0,
          'rol': 'admin',
          'creado_en': FieldValue.serverTimestamp(),
        });
        return cred;
      }
      rethrow;
    }
  }

  /// Crea (o inicia sesión si ya existe) una cuenta con un rol específico
  /// ('admin' o 'cliente'). Garantiza que el doc de Firestore quede con ese rol.
  Future<UserCredential> asegurarCuentaConRol({
    required String email,
    required String password,
    required String rol,
  }) async {
    // SEGURIDAD: idem asegurarCuentaDemo - solo debug.
    if (!kDebugMode) {
      throw StateError('asegurarCuentaConRol solo está disponible en debug.');
    }
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user?.uid;
        if (uid == null) {
          throw Exception('No se pudo obtener el uid');
        }
        await _db.collection('usuarios').doc(uid).set({
          'uid': uid,
          'nombre': rol == 'admin' ? 'Admin Demo' : 'Cliente Demo',
          'email': email,
          'telefono': '',
          'direccion': '',
          'tokens_balance': 0,
          'rol': rol,
          'creado_en': FieldValue.serverTimestamp(),
        });
        return cred;
      }
      rethrow;
    }
  }

  /// Solo se permite iniciar sesión con cuentas @gmail.com.
  /// Cualquier otro dominio devuelve false y la UI muestra "dominio desconocido".
  static bool esDominioGmail(String email) {
    return email.trim().toLowerCase().endsWith('@gmail.com');
  }
}
