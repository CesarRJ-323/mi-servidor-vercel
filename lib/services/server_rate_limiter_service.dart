import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Servicio cliente para rate limiting server-side.
///
/// Delega la validación de límites a Cloud Functions, que usan Firestore
/// para persistir contadores por IP + UID. Esto evita que un bot rooteado
/// pueda bypassar el rate limiting local.
///
/// Uso:
/// final result = await ServerRateLimiter.check(
///   functions: FirebaseFunctions.instance,
///   accion: 'login_attempts',
///   identificador: email,
/// );
abstract class ServerRateLimiter {
  ServerRateLimiter._(); // Esta clase no se instancia

  /// Verifica si una acción está permitida server-side.
  ///
  /// [accion] debe ser una de: 'login_attempts', 'account_creation', 'sorteo_participation'
  /// [identificador] debe ser el UID del usuario o su email/IP
  ///
  /// Devuelve:
  /// {
  ///   'allowed': true/false,
  ///   'remaining': int,      // intentos restantes
  ///   'reset_in': int,       // segundos hasta reset
  ///   'message': String?     // mensaje de error si blocked
  /// }
  static Future<Map<String, dynamic>> check({
    required FirebaseFunctions functions,
    required String accion,
    required String identificador,
  }) async {
    try {
      final HttpsCallable callable = functions.httpsCallable('rateLimit');

      final result = await callable.call({
        'action': accion,
        'identifier': identificador,
      });

      return {
        'allowed': result.data['allowed'] ?? false,
        'remaining': result.data['remaining'] ?? 0,
        'reset_in': result.data['reset_in'] ?? 60,
        'message': result.data['message'] as String?,
      };
    } on FirebaseFunctionsException catch (e) {
      // Si falla la llamada (timeout, red, etc), permitimos (fail-open)
      // Esto previene falsos positivos en usuarios legítimos
      debugPrint('[ServerRateLimiter] Error check: $e');
      // NOTA: En producción podés cambiar a fail-close si es crítico
      return {
        'allowed': true,
        'remaining': 1,
        'reset_in': 0,
        'message': null,
      };
    } catch (e) {
      debugPrint('[ServerRateLimiter] Unexpected error: $e');
      return {
        'allowed': true,
        'remaining': 1,
        'reset_in': 0,
        'message': null,
      };
    }
  }
}
