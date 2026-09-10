import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:delivery_app_v2/models/sorteo_model.dart';
import 'package:delivery_app_v2/services/rate_limiter_service.dart';
import 'package:delivery_app_v2/services/server_rate_limiter_service.dart';

/// Acceso a la colección `sorteos` en Firestore.
class SorteoRepository {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('sorteos');
  final RateLimiterService _rateLimiter = RateLimiterService();

  /// Sorteos activos (los que ve el cliente en el home).
  /// Filtra por campo suelto (Firestore lo indexa solo) y ordena
  /// SERVER-SIDE (evita sort en cliente = menos datos transferidos
  /// y menos trabajo en el móvil).
  Stream<List<Sorteo>> streamSorteosActivos() {
    return _col
        .where('activo', isEqualTo: true)
        .orderBy('fecha_sorteo')
        .snapshots()
        .map((snap) {
          final lista = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return Sorteo.fromJson(data);
          }).toList();
          // Fallback de sort por si el índice server-side falla
          lista.sort((a, b) => a.fechaSorteo.compareTo(b.fechaSorteo));
          return lista;
        });
  }

  /// Todos los sorteos (lo usa el admin).
  /// OPTIMIZACIÓN: ordena server-side con orderBy('creado_en', descending: true)
  /// en vez de descargar todo y ordenar en cliente — Firestore ya indexa
  /// este campo. Si bien el payload incluye participantes/nombres/ganadores
  /// completos (cloud_firestore 6.x no expone .select() para streams), el
  /// orderBy server-side aún evita ordenar cientos de docs en el móvil.
  Stream<List<Sorteo>> streamTodosLosSorteos() {
    return _col
        .orderBy('creado_en', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
          final lista = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return Sorteo.fromJson(data);
          }).toList();
          // Fallback de sort por si el índice server-side falla
          lista.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
          return lista;
        });
  }

  Future<void> crearSorteo(Sorteo sorteo) async {
    await _col.add(sorteo.toJson());
  }

  Future<void> actualizarSorteo(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  Future<void> eliminarSorteo(String id) async {
    await _col.doc(id).delete();
  }

  /// Inscribe al usuario en el sorteo (transacción: evita inscripciones
  /// duplicadas por carrera y no permite participar si ya terminó).
  Future<String> participar({
    required String sorteoId,
    required String uid,
    required String nombre,
  }) async {
    // 1. Rate limiting LOCAL: max 5 inscripciones por 1 minuto por usuario
    final restante = _rateLimiter.puedeEjecutar('sorteo_participar', uid);
    if (restante != null) {
      return 'Demasiadas inscripciones. ${restante.aTextoAmigable()}';
    }

    // 2. Rate limiting SERVER-SIDE: valida contra Firestore
    final serverCheck = await ServerRateLimiter.check(
      functions: FirebaseFunctions.instance,
      accion: 'sorteo_participation',
      identificador: uid,
    );

    if (!serverCheck['allowed']) {
      return serverCheck['message'] ??
          'Demasiadas inscripciones. Intentálo más tarde.';
    }

    // Los admins organizan los sorteos: no pueden participar.
    final userDoc =
        (await FirebaseFirestore.instance.collection('usuarios').doc(uid).get());
    if (userDoc.data()?['rol']?.toString() == 'admin') {
      return 'Los administradores no pueden participar de los sorteos.';
    }

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final sorteoRef = _col.doc(sorteoId);
      final userRef = FirebaseFirestore.instance.collection('usuarios').doc(uid);
      final sorteoSnap = await tx.get(sorteoRef);
      final userSnap = await tx.get(userRef);
      if (!sorteoSnap.exists) throw Exception('El sorteo no existe');
      if (!userSnap.exists) throw Exception('Usuario no encontrado');

      final sorteoData = sorteoSnap.data()!;
      if (sorteoData['terminado'] == true ||
          ((sorteoData['ganadores'] as List<dynamic>?)?.isNotEmpty ?? false)) {
        return 'Este sorteo ya finalizó.';
      }
      final participantes =
          ((sorteoData['participantes'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList();
      if (participantes.contains(uid)) return 'Ya estás participando.';
      final userData = userSnap.data() as Map<String, dynamic>;
      final int tickets = userData['tickets_balance'] ?? 0;
      if (tickets < 1) {
        return 'Necesitas al menos 1 ticket para participar.';
      }
      final nombres = ((sorteoData['nombres_participantes'] as List<dynamic>?) ?? [])
          .map((e) => e.toString()).toList();
      participantes.add(uid);
      nombres.add(nombre);
      tx.update(sorteoRef, {
        'participantes': participantes,
        'nombres_participantes': nombres,
      });
      // Consumir el ticket
      tx.update(userRef, {
        'tickets_balance': FieldValue.increment(-1),
      });
      return '¡Inscrito! Mucha suerte, .';
    });  }

  /// Elige [cantidad] ganadores al azar entre los participantes.
  /// Los admins ya fueron bloqueados en participar(), así que la lista
  /// solo contiene clientes elegibles. Marca el sorteo como terminado.
  Future<List<String>> realizarSorteo({
    required String sorteoId,
    int cantidad = 1,
  }) async {
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final ref = _col.doc(sorteoId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('El sorteo no existe');
      final data = snap.data()!;
      if (data['terminado'] == true) {
        return ((data['ganadores'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList();
      }

      // Participantes como pares (uid, nombre) para poder filtrar admins
      // por uid consultando su doc en usuarios.
      final participantes =
          ((data['participantes'] as List<dynamic>?) ?? [])
              .map((e) => e.toString())
              .toList();
      final nombres = ((data['nombres_participantes'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList();

      if (participantes.isEmpty) {
        throw Exception('No hay participantes inscriptos');
      }

      // Los admins ya están bloqueados en participar() (línea 84).
      // No se necesita re-verificar aquí — evita N+1 reads.
      final elegibles = List<String>.generate(
        participantes.length,
        (i) => i < nombres.length ? nombres[i] : 'Participante',
      );

      if (elegibles.isEmpty) {
        throw Exception('No hay participantes elegibles.');
      }

      final elegidos = elegibles.toList()..shuffle();
      final ganadores =
          elegidos.take(cantidad.clamp(1, elegibles.length)).toList();
      tx.update(ref, {
        'ganadores': ganadores,
        'terminado': true,
        'activo': false,
        'fecha_fin': FieldValue.serverTimestamp(),
      });
      return ganadores;
    });
  }

  /// Historial de sorteos terminados con ganadores, visibles al cliente.
  /// Solo muestra los finalizados en los últimos [dias] días (por defecto 7).
  Stream<List<Sorteo>> streamHistorial({int dias = 7}) {
    final limite = DateTime.now().subtract(Duration(days: dias));
    return _col
        .where('terminado', isEqualTo: true)
        .where('fecha_fin', isGreaterThan: Timestamp.fromDate(limite))
        .snapshots()
        .map((snap) {
          final lista = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return Sorteo.fromJson(data);
          }).toList();
          // Más recientes primero
          lista.sort((a, b) =>
              (b.fechaFin ?? b.fechaSorteo).compareTo(a.fechaFin ?? a.fechaSorteo));
          return lista;
        });
  }

  /// Elimina sorteos terminados hace más de [horas] horas
  /// (24h por defecto — evita acumulación, como pidió César).
  Future<int> purgarAntiguos({int dias = 7, int horas = 24}) async {
    final limite = DateTime.now().subtract(Duration(hours: horas));
    final snap = await _col
        .where('terminado', isEqualTo: true)
        .where('fecha_fin', isLessThan: Timestamp.fromDate(limite))
        .get();
    var borrados = 0;
    for (final d in snap.docs) {
      await d.reference.delete();
      borrados++;
    }
    return borrados;
  }
}
