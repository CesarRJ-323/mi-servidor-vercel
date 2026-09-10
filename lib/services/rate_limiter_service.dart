import 'package:flutter/foundation.dart' show kDebugMode;

/// Rate limiter en memoria para prevenir spam/ataques locales.
/// Limita por [accion] + [identificador] (uid o IP).
/// Las ventanas de tiempo se reinician después de [duracionBloqueo].
class RateLimiterService {
  /// Mapa en memoria: accion -> identificador -> lista de timestamps.
  final Map<String, Map<String, List<int>>> _acciones = {};

  /// Límite de intentos permitidos en [ventanaMillis] milisegundos.
  final int maxIntentos;
  final int ventanaMillis;

  /// Duración del bloqueo después de exceder el límite.
  final int duracionBloqueo;

  RateLimiterService({
    this.maxIntentos = 5,
    this.ventanaMillis = 60000, // 1 minuto
    this.duracionBloqueo = 60000, // 1 minuto de bloqueo
  });

  /// Verifica si [accion] está permitida para [identificador].
  /// Devuelve null si está permitida, o el tiempo restante de bloqueo en ms.
  int? puedeEjecutar(String accion, String identificador) {
    final ahora = DateTime.now().millisecondsSinceEpoch;

    _acciones.putIfAbsent(accion, () => {});
    _acciones[accion]!.putIfAbsent(identificador, () => []);

    final lista = _acciones[accion]![identificador]!;

    // Limpiar timestamps viejos (fuera de la ventana)
    lista.removeWhere((ts) => (ahora - ts) > ventanaMillis);

    // Si está en ventana normal y no excedió → OK
    if (lista.length < maxIntentos) {
      lista.add(ahora);
      return null;
    }

    // Si excedió → calcular tiempo restante de bloqueo
    final ultima = lista.last;
    final tiempoRestante = duracionBloqueo - (ahora - ultima);
    if (tiempoRestante > 0) {
      return tiempoRestante;
    } else {
      // El bloqueo expiró → resetear contador y permitir
      lista.clear();
      lista.add(ahora);
      return null;
    }
  }

  /// Formatea el tiempo restante para mostrar al usuario.
  String formatoTiempoRestante(int msRestantes) {
    final segundos = (msRestantes / 1000).ceil();
    if (segundos <= 0) return 'Intentálo más tarde';
    return 'Intentálo en ${segundos}s';
  }

  /// DEBUG opcional para inspeccionar estado
  void debugEstado() {
    if (kDebugMode) {
      print('[RateLimiter] Estado: $_acciones');
    }
  }
}

/// Extension para formatear milisegundos a texto legible.
extension TiempoRestanteExtension on int {
  String aTextoAmigable() {
    final totalSegundos = (this / 1000).ceil();
    if (totalSegundos < 60) return '${totalSegundos}s';
    final minutos = totalSegundos ~/ 60;
    final segundos = totalSegundos % 60;
    return '${minutos}m ${segundos}s';
  }
}
