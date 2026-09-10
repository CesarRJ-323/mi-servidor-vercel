class Sorteo {
  final String id;
  final String titulo;
  final String descripcion;
  final String premio;
  final DateTime fechaSorteo;
  final String imagenUrl;
  final bool activo;
  final DateTime creadoEn;
  final int cantidadGanadores; // cuántos ganadores se eligen al azar
  final List<String> participantes; // uids inscriptos
  final List<String> nombresParticipantes; // nombres en el mismo orden
  final List<String> ganadores; // nombres elegidos al azar
  final bool terminado; // true = ya se realizó el sorteo
  final DateTime? fechaFin; // cuándo se realizó

  Sorteo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.premio,
    required this.fechaSorteo,
    this.imagenUrl = '',
    this.activo = true,
    required this.creadoEn,
    this.cantidadGanadores = 1,
    List<String>? participantes,
    List<String>? nombresParticipantes,
    List<String>? ganadores,
    this.terminado = false,
    this.fechaFin,
  })  : participantes = participantes ?? [],
        nombresParticipantes = nombresParticipantes ?? [],
        ganadores = ganadores ?? [];

  bool get finalizado => terminado || ganadores.isNotEmpty;

  factory Sorteo.fromJson(Map<String, dynamic> json) => Sorteo(
        id: json['id'] ?? '',
        titulo: json['titulo'] ?? '',
        descripcion: json['descripcion'] ?? '',
        premio: json['premio'] ?? '',
        fechaSorteo: _parseFecha(json['fecha_sorteo']) ?? DateTime.now(),
        imagenUrl: json['imagen_url'] ?? '',
        activo: json['activo'] ?? true,
        creadoEn: _parseFecha(json['creado_en']) ?? DateTime.now(),
        cantidadGanadores: json['cantidad_ganadores'] ?? 1,
        participantes: (json['participantes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        nombresParticipantes: (json['nombres_participantes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        ganadores: (json['ganadores'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        terminado: json['terminado'] ?? false,
        fechaFin: _parseFecha(json['fecha_fin']),
      );

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'premio': premio,
        'fecha_sorteo': fechaSorteo.toIso8601String(),
        'imagen_url': imagenUrl,
        'activo': activo,
        'creado_en': creadoEn.toIso8601String(),
        'cantidad_ganadores': cantidadGanadores,
        'participantes': participantes,
        'nombres_participantes': nombresParticipantes,
        'ganadores': ganadores,
        'terminado': terminado,
        'fecha_fin': fechaFin?.toIso8601String(),
      };

  /// Acepta Timestamp de Firestore, ISO String o null sin crashear.
  static DateTime? _parseFecha(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      final ms = (v as dynamic).millisecondsSinceEpoch;
      if (ms is int) return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    return DateTime.tryParse(v.toString());
  }
}
