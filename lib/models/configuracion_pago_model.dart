import 'package:cloud_firestore/cloud_firestore.dart';

class ConfiguracionPago {
  final String aliasPago;
  final String instrucciones;
  final bool activo;
  final DateTime? actualizadoEn;

  ConfiguracionPago({
    required this.aliasPago,
    required this.instrucciones,
    required this.activo,
    this.actualizadoEn,
  });

  factory ConfiguracionPago.fromJson(Map<String, dynamic> json) {
    return ConfiguracionPago(
      aliasPago: json['aliasPago'] ?? '',
      instrucciones: json['instrucciones'] ?? '',
      activo: json['activo'] ?? false,
      actualizadoEn: json['actualizadoEn'] != null
          ? (json['actualizadoEn'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aliasPago': aliasPago,
      'instrucciones': instrucciones,
      'activo': activo,
      'actualizadoEn': actualizadoEn != null
          ? Timestamp.fromDate(actualizadoEn!)
          : null,
    };
  }
}