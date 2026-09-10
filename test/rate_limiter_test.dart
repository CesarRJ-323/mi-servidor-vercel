import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app_v2/services/rate_limiter_service.dart';

/// Tests para verificar que el rate limiting funciona correctamente.
void main() {
  group('RateLimiterService', () {
    late RateLimiterService rateLimiter;

    setUp(() {
      rateLimiter = RateLimiterService(
        maxIntentos: 3,
        ventanaMillis: 5000, // 5 segundos de ventana de prueba
        duracionBloqueo: 10000, // 10 segundos de bloqueo
      );
    });

    test('Permite hasta maxIntentos', () {
      // Intento 1, 2, 3 → deben ser null (permitidos)
      expect(rateLimiter.puedeEjecutar('test_accion', 'user1@test.com'), isNull);
      expect(rateLimiter.puedeEjecutar('test_accion', 'user1@test.com'), isNull);
      expect(rateLimiter.puedeEjecutar('test_accion', 'user1@test.com'), isNull);
    });

    test('Bloquea después de maxIntentos excedidos', () {
      // Primeros 3 permitidos
      rateLimiter.puedeEjecutar('test_accion', 'user1@test.com');
      rateLimiter.puedeEjecutar('test_accion', 'user1@test.com');
      rateLimiter.puedeEjecutar('test_accion', 'user1@test.com');

      // 4to intento → debe devolver tiempo restante de bloqueo (no null)
      final restante = rateLimiter.puedeEjecutar('test_accion', 'user1@test.com');
      expect(restante, isNotNull);
      expect(restante, greaterThan(0));
    });

    test('Devuelve tiempo restante formateado correctamente', () {
      // Agotar intentos
      for (int i = 0; i < 3; i++) {
        rateLimiter.puedeEjecutar('test_accion', 'user2@test.com');
      }
      final restante = rateLimiter.puedeEjecutar('test_accion', 'user2@test.com');
      expect(rateLimiter.formatoTiempoRestante(restante!), contains('Intentálo en'));
    });

    test('Acciones diferentes tienen contadores independientes', () {
      // Login 3 veces
      for (int i = 0; i < 3; i++) {
        expect(rateLimiter.puedeEjecutar('login', 'user@test.com'), isNull);
      }
      // Login ahora bloqueado
      expect(rateLimiter.puedeEjecutar('login', 'user@test.com'), isNotNull);

      // Registro debe seguir permitido
      expect(rateLimiter.puedeEjecutar('registro', 'user@test.com'), isNull);
    });

    test('Usuarios diferentes no se bloquean entre sí', () {
      // user1 agota intentos
      for (int i = 0; i < 3; i++) {
        rateLimiter.puedeEjecutar('login', 'user1@test.com');
      }
      expect(rateLimiter.puedeEjecutar('login', 'user1@test.com'), isNotNull);

      // user2 debe estar OK
      expect(rateLimiter.puedeEjecutar('login', 'user2@test.com'), isNull);
    });

    test('Extensión aTextoAmigable formatea correctamente', () {
      expect(30000.aTextoAmigable(), '30s');
      expect(75000.aTextoAmigable(), '1m 15s');
      expect(120000.aTextoAmigable(), '2m 0s');
    });
  });
}
