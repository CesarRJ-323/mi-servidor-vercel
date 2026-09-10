import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const accessToken = 'APP_USR-6200570129811424-090718-3eae0ffa5756529ce513fe17560a6a82-3670768195';
  
  final body = {
    'items': [
      {
        'title': 'Test Item',
        'quantity': 1,
        'currency_id': 'ARS',
        'unit_price': 100.0,
      }
    ],
    'back_urls': {
      'success': 'rapidiya://pago/exito',
      'failure': 'rapidiya://pago/fallo',
      'pending': 'rapidiya://pago/pendiente',
    },
    'auto_return': 'approved',
    'external_reference': 'test_ref_123',
  };

  final resp = await http.post(
    Uri.parse('https://api.mercadopago.com/checkout/preferences'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  print('Status code: ${resp.statusCode}');
  print('Body: ${resp.body}');
}
