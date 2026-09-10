import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificación local del sistema: "¡Ganaste el sorteo!".
/// Se muestra al abrir la app si el usuario logueado es ganador de un
/// sorteo terminado reciente.
class NotificacionesGanaste {
  NotificacionesGanaste._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static const _channel = AndroidNotificationChannel(
    'ganaste_sorteos',
    'Ganaste sorteos',
    description: 'Avisos cuando ganás un sorteo de Rapidiya',
    importance: Importance.high,
  );

  static Future<void> inicializar() async {
    if (_inicializado) return;
    const initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: initAndroid),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    _inicializado = true;
  }

  /// Muestra la notificación "¡Felicitaciones, ganaste!".
  static Future<void> notificarGanaste({
    required String nombreSorteo,
    required String premio,
  }) async {
    await inicializar();
    await _plugin.show(
      nombreSorteo.hashCode, // id estable por sorteo
      '¡Felicitaciones, ganaste! 🏆',
      'Ganaste "$nombreSorteo". Premio: $premio',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            'Ganaste "$nombreSorteo". Premio: $premio. '
            'Entrá a la sección Sorteos para ver el detalle.',
          ),
        ),
      ),
    );
  }
}
