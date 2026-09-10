import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app_v2/models/usuario_model.dart';

/// Lectura/escritura de la colección `usuarios`.
class UsuarioRepository {
  final FirebaseFirestore _db;

  UsuarioRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('usuarios');

  Future<Usuario?> getUsuario(String uid) async {
    final snap = await _col.doc(uid).get();
    if (!snap.exists) return null;
    return Usuario.fromJson({'uid': snap.id, ...snap.data()!});
  }

  Future<void> crearUsuario(Usuario usuario) async {
    await _col.doc(usuario.uid).set(usuario.toJson());
  }

  Future<void> actualizarUsuario(String uid, Map<String, dynamic> datos) async {
    await _col.doc(uid).update(datos);
  }

  /// Suma tokens al saldo del usuario (para canjes/promos).
  Future<void> sumarTokens(String uid, int cantidad) async {
    await _col.doc(uid).update({
      'tokens_balance': FieldValue.increment(cantidad),
    });
  }
}
