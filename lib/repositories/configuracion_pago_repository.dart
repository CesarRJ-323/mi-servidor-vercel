// lib/repositories/configuracion_pago_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/configuracion_pago_model.dart';

class ConfiguracionPagoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ConfiguracionPago?> obtenerConfiguracion() async {
    try {
      final doc = await _db
          .collection('configuracion')
          .doc('pago_alternativo')
          .get();

      if (doc.exists) {
        return ConfiguracionPago.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      // Log error but don't crash
      return null;
    }
  }

  Future<void> guardarConfiguracion(ConfiguracionPago config) async {
    try {
      await _db
          .collection('configuracion')
          .doc('pago_alternativo')
          .set(config.toJson());
    } catch (e) {
      rethrow;
    }
  }
}