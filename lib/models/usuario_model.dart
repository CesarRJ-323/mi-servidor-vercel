class Usuario {
  final String uid;
  final String nombre;
  final String email;
  final String telefono;
  final String direccion;
  final String mapsUrl; // link opcional de Google Maps
  final String descripcionCasa; // pista obligatoria para el delivery
  final double? latitud;
  final double? longitud;
  final int tokensBalance;
  final bool esAdmin;
  final String? urlFoto;

  Usuario({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.direccion,
    this.mapsUrl = '',
    this.descripcionCasa = '',
    this.latitud,
    this.longitud,
    this.tokensBalance = 0,
    this.esAdmin = false,
    this.urlFoto,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        uid: json['uid'] ?? '',
        nombre: json['nombre'] ?? '',
        email: json['email'] ?? '',
        telefono: json['telefono'] ?? '',
        direccion: json['direccion'] ?? '',
        mapsUrl: json['maps_url'] ?? '',
        descripcionCasa: json['descripcion_casa'] ?? '',
        latitud: json['latitud']?.toDouble(),
        longitud: json['longitud']?.toDouble(),
        tokensBalance: json['tokens_balance'] ?? 0,
        esAdmin: json['rol'] == 'admin',
        urlFoto: json['url_foto'],
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'direccion': direccion,
        'maps_url': mapsUrl,
        'descripcion_casa': descripcionCasa,
        'latitud': latitud,
        'longitud': longitud,
        'tokens_balance': tokensBalance,
        'rol': esAdmin ? 'admin' : 'cliente',
        'url_foto': urlFoto,
      };
}
