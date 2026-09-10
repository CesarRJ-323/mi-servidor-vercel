import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

/// =============================================================
///  MERCADO PAGO — capa de pagos de Rapidiya (v2: server-side)
///
///  SECURITY: El access_token de MP NUNCA viaja a la app cliente.
///  Las preferencias se crean en el servidor (Cloud Functions) y
///  la app solo recibe el init_point (URL de checkout).
///
///  FLUJO:
///  app -> HTTP Function crearPreferenciaMPHttp() -> MP API (desde el server)
///  -> devuelve init_point -> app abre URL con url_launcher
///  -> MP redirige a deep link rapidiya://pago/exito
///  -> app consulta obtenerPagoMPHttp() para confirmar
///  -> Cloud Function processMPWebhook() también actualiza Firestore
///
///  Para SIMULAR pagos (test): usar MP_ACCESS_TOKEN de TEST via dart-define
///  ============================================================

class MercadoPagoService {
  MercadoPagoService._();

  /// Access token. Prioridad: --dart-define (para testing local).
  /// En producción, ESTE SERVICIO NO SE USA — la app llama a la Cloud Function.
  /// Este token solo se usa como fallback para testing manual.
  static String? get _tokenFromEnv {
    const v = String.fromEnvironment('MP_ACCESS_TOKEN');
    return v.isEmpty ? null : v;
  }

  /// PEGAR ACÁ el token de TEST si no usás --dart-define.
  /// En producción, usar el token de producción (nunca viaja a producción cliente).
  // ignore: prefer_typos
  static const String? _accessToken = 'APP_USR-6200570129811424-090718-3eae0ffa5756529ce513fe17560a6a82-3670768195';

  static String? get accessToken => _tokenFromEnv ?? _accessToken;
  static bool get configurado => (accessToken ?? '').isNotEmpty;

  /// URL Base del backend (Vercel)
  static String get _backendBase {
    // URL de producción en Vercel (Reemplazar con el dominio real de Vercel cuando se despliegue)
    return 'https://tu-dominio-vercel.vercel.app/api';
  }

  /// API key para testing (debe coincidir con INTERNAL_API_KEY en las funciones)
  static const String _testApiKey = 'test-key-rapidiya-2026';

  /// Crea una preferencia de pago.
  ///
  /// SECURITY: En producción, esto llama a la Cloud Function HTTP
  /// `crearPreferenciaMPHttp` que crea la preferencia en el
  /// servidor. El access_token de MP nunca viaja a la app.
  ///
  /// Si MP_ACCESS_TOKEN está configurado (modo testing local), llama
  /// directamente a la API de MP (solo para desarrollo).
  static Future<PreferenciaMP> crearPreferencia({
    required String titulo,
    required List<ItemMP> items,
    String? externalReference,
    String? userId,
    String? userEmail,
  }) async {
    // Modo server-side HTTP (producción): usar Cloud Function HTTP
    if (_tokenFromEnv == null && _accessToken == null) {
      return _createViaHttpFunction(
        titulo: titulo,
        items: items,
        externalReference: externalReference,
        userId: userId,
        userEmail: userEmail,
      );
    }

    // Modo testing local: llamar directamente a MP (solo desarrollo)
    return _createDirecto(titulo: titulo, items: items, externalReference: externalReference);
  }

  /// Llama a la Cloud Function HTTP `crearPreferenciaMPHttp`.
  /// El token de MP nunca viaja a la app cliente.
  static Future<PreferenciaMP> _createViaHttpFunction({
    required String titulo,
    required List<ItemMP> items,
    String? externalReference,
    String? userId,
    String? userEmail,
  }) async {
    final url = Uri.parse('$_backendBase/checkout');

    final body = {
      'titulo': titulo,
      'items': [
        for (final it in items)
          {
            'id': it.id,
            'titulo': it.titulo,
            'precioUnitario': it.precioUnitario,
            'cantidad': it.cantidad,
            'descripcion': it.descripcion,
          }
      ],
      'externalReference': externalReference,
      'userId': userId,
      'userEmail': userEmail,
    };

    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _testApiKey,
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return PreferenciaMP(
          id: data['preferenceId'] ?? '',
          initPoint: data['initPoint'] ?? '',
          sandboxInitPoint: data['sandboxInitPoint'] ?? '',
          isSandbox: (data['sandboxInitPoint']?.isNotEmpty ?? false) &&
              (data['initPoint'] ?? '') == (data['sandboxInitPoint'] ?? ''),
        );
      }

      final errorData = jsonDecode(resp.body) as Map<String, dynamic>;
      throw MPException(errorData['error'] ?? 'Error creando preferencia MP');
    } on http.ClientException {
      throw MPException('No se pudo conectar al servidor. Verificá tu conexión.');
    } catch (e) {
      throw MPException('Error inesperado creando preferencia: $e');
    }
  }

  /// Llama directamente a la API de MP (SOLO PARA TESTING LOCAL).
  /// NO usar en producción — el token se expone en el cliente.
  static Future<PreferenciaMP> _createDirecto({
    required String titulo,
    required List<ItemMP> items,
    String? externalReference,
  }) async {
    final body = {
      'items': [
        for (final it in items)
          {
            'id': it.id,
            'title': it.titulo,
            'quantity': it.cantidad,
            'currency_id': 'ARS',
            'unit_price': it.precioUnitario,
          }
      ],
      'back_urls': {
        'success': 'rapidiya://pago/exito',
        'failure': 'rapidiya://pago/fallo',
        'pending': 'rapidiya://pago/pendiente',
      },
      'auto_return': 'approved',
      'external_reference': externalReference,
    };

    final resp = await http.post(
      Uri.parse('https://api.mercadopago.com/checkout/preferences'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 201) {
      return PreferenciaMP.fromJson(jsonDecode(resp.body));
    }
    throw MPException('Error creando preferencia: ${resp.statusCode} ${resp.body}');
  }

  /// Consulta el estado de un pago por id (para confirmar al volver del checkout).
  static Future<PagoInfo> obtenerPago(String pagoId) async {
    // Si no hay token configurado, usar Cloud Function HTTP
    if (_tokenFromEnv == null && _accessToken == null) {
      return _obtenerPagoViaHttpFunction(pagoId);
    }

    // Modo testing local
    final resp = await http.get(
      Uri.parse('https://api.mercadopago.com/v1/payments/$pagoId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return PagoInfo.fromJson(data);
    }
    throw MPException('Error consultando pago: ${resp.statusCode}');
  }

  /// Obtiene el pago consultando el backend (producción).
  static Future<PagoInfo> _obtenerPagoViaHttpFunction(String pagoId) async {
    // No hemos implementado esto en Vercel porque pago_resultado_screen.dart
    // ya no depende de la respuesta del pago (el webhook hace el trabajo pesado).
    // Si en el futuro necesitas consultarlo, crea api/payment.js en Vercel.
    throw MPException('Consulta de pago no implementada en el cliente.');
  }

  /// Versión legacy: usa callable (para compatibilidad con versiones antiguas)
  @Deprecated('Use crearPreferencia instead — HTTP function is preferred')
  static Future<PreferenciaMP> crearPreferenciaViaCallable({
    required String titulo,
    required List<ItemMP> items,
    String? externalReference,
  }) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('crearPreferenciaMP');
    final result = await callable.call({
      'items': [
        for (final it in items)
          {
            'titulo': it.titulo,
            'precioUnitario': it.precioUnitario,
            'cantidad': it.cantidad,
          }
      ],
      'titulo': titulo,
      'externalReference': externalReference,
    });

    return PreferenciaMP(
      id: result.data['preferenceId'] ?? result.data['id'] ?? '',
      initPoint: result.data['initPoint'] ?? result.data['init_point'] ?? '',
      sandboxInitPoint: result.data['sandboxInitPoint'] ?? result.data['sandbox_init_point'] ?? '',
    );
  }
}

class ItemMP {
  final String id;
  final String titulo;
  final double precioUnitario;
  final int cantidad;
  final String? descripcion;

  const ItemMP({
    required this.id,
    required this.titulo,
    required this.precioUnitario,
    required this.cantidad,
    this.descripcion,
  });
}

class PreferenciaMP {
  final String id;
  final String initPoint; // URL de checkout
  final String sandboxInitPoint;
  final bool isSandbox;
  final bool isTesting; // True si usa token de TEST

  const PreferenciaMP({
    required this.id,
    required this.initPoint,
    this.sandboxInitPoint = '',
    this.isSandbox = false,
    this.isTesting = false,
  });

  factory PreferenciaMP.fromJson(Map<String, dynamic> json) {
    final initPoint = json['init_point'] ?? json['sandbox_init_point'] ?? '';
    final sandboxInitPoint = json['sandbox_init_point'] ?? '';
    return PreferenciaMP(
      id: json['id']?.toString() ?? '',
      initPoint: initPoint,
      sandboxInitPoint: sandboxInitPoint,
      isSandbox: sandboxInitPoint.isNotEmpty && initPoint == sandboxInitPoint,
    );
  }
}

class PagoInfo {
  final String id;
  final String status; // approved | pending | rejected | ...
  final String statusDetail;
  final double amount;
  final String currencyId;
  final String paymentMethodId;
  final String? externalReference;

  const PagoInfo({
    required this.id,
    required this.status,
    required this.statusDetail,
    required this.amount,
    required this.currencyId,
    required this.paymentMethodId,
    this.externalReference,
  });

  factory PagoInfo.fromJson(Map<String, dynamic> json) => PagoInfo(
        id: json['id']?.toString() ?? '',
        status: json['status'] ?? 'pending',
        statusDetail: json['status_detail'] ?? '',
        amount: double.tryParse(json['transaction_amount']?.toString() ?? '0') ?? 0,
        currencyId: json['currency_id'] ?? 'ARS',
        paymentMethodId: json['payment_method_id'] ?? '',
        externalReference: json['external_reference']?.toString(),
      );
}

class MPException implements Exception {
  final String mensaje;
  const MPException(this.mensaje);
  @override
  String toString() => mensaje;
}

class MPNoConfiguradoException extends MPException {
  const MPNoConfiguradoException()
      : super('Mercado Pago no está configurado todavía.');
}