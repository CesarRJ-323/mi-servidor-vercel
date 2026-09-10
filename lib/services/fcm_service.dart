import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio de Firebase Cloud Messaging (FCM) para notificaciones push.
///
/// Responsabilidades:
///   - Pedir permiso de notificaciones (Android 13+ runtime, iOS).
///   - Obtener y refrescar el token FCM, guardándolo en Firestore (`usuarios/{uid}.fcm_token`).
///   - Configurar handlers para foreground, background y notificación tocada.
///   - Mostrar notificaciones locales usando flutter_local_notifications.
///
/// Para la navegación al tocar la notificación, se usa un callback global
/// [onNotificationTap] que se setea en main() con un navigatorKey.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'nuevos_sorteos',
    'Nuevos sorteos',
    description: 'Cuando se publica un nuevo sorteo en Rapidiya',
    importance: Importance.high,
  );

  /// Callback global: se ejecuta cuando el usuario toca una notificación.
  /// Setearlo en main() con un navigatorKey.
  static void Function(RemoteMessage message)? onNotificationTap;

  /// Inicializa FCM: canal, permisos, handlers, token y listener global.
  /// Debe llamarse en [main] ANTES de [runApp].
  static Future<void> initialize() async {
    // 1. Crear el canal de notificación en Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 2. Pedir permisos (Android 13+ runtime; iOS siempre)
    await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      sound: true,
    );

    // 3. Configurar flutter_local_notifications para mostrar notificaciones
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: initAndroid),
    );

    // 4. Subscribirse globalmente al refresh de token (se mantiene activo
    //    toda la vida de la app y guarda en Firestore cuando hay usuario logueado)
    _escucharTokenRefresh();

    // 5. Handler: app en foreground — mostrar notificación local inmediatamente
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _mostrarNotificacionLocal(message);
    });

    // 6. Handler: notificación tocada (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap?.call(message);
    });

    // 7. Verificar si la app fue abierta desde terminated state (notificación tocada)
    _verificarNotificacionInicial();

    // 8. Si el usuario ya está logueado al iniciar, refrescar token inmediatamente
    _refrescarTokenSiLogueado();
  }

  /// Verifica si la app fue abierta tocando una notificación (terminated state).
  static Future<void> _verificarNotificacionInicial() async {
    final RemoteMessage? message = await _messaging.getInitialMessage();
    if (message != null) {
      onNotificationTap?.call(message);
    }
  }

  /// Subscripción global a onTokenRefresh.
  /// El token puede cambiar por cualquier motivo del sistema, así que nos
  /// subscribimos una vez en initialize() y siempre que el usuario esté logueado,
  /// guardamos el token actualizado en Firestore.
  static void _escucharTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({'fcm_token': token}, SetOptions(merge: true));
      }
    });
  }

  /// Si hay usuario logueado, obtiene su token y lo guarda en Firestore.
  static void _refrescarTokenSiLogueado() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    guardarTokenParaUsuario(user.uid);
  }

  /// Obtiene el token FCM y lo guarda en el documento del usuario.
  /// Se puede llamar explícitamente después de un login exitoso
  /// o cuando el usuario se registra.
  static Future<void> guardarTokenParaUsuario(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set({'fcm_token': token}, SetOptions(merge: true));
      }
    } catch (e) {
      // No bloquear el login si falla el token FCM
    }
  }

  /// Muestra una notificación local a partir de un RemoteMessage.
  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      final body = notification.body ?? '¡Nuevo sorteo disponible!';
      await _localNotif.show(
        notification.hashCode,
        notification.title ?? 'Rapidiya',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        payload: message.data['giveaway_id'] ?? '',
      );
    }
  }

  /// Limpia el token del usuario al desloguearse.
  static Future<void> desuscribir() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .set({'fcm_token': FieldValue.delete()}, SetOptions(merge: true));
    }
  }
}
