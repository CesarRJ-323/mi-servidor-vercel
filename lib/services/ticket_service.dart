import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  /// Compra 1 ticket a cambio de 5 tokens. Devuelve true si tuvo éxito.
  Future<bool> comprarTicketConTokens() async {
    if (_uid.isEmpty) return false;
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('usuarios').doc(_uid);
        final snap = await transaction.get(docRef);
        if (!snap.exists) throw Exception('Usuario no encontrado');
        
        final data = snap.data() as Map<String, dynamic>;
        final int tokens = data['tokens_balance'] ?? 0;
        if (tokens < 5) throw Exception('Tokens insuficientes');
        
        transaction.update(docRef, {
          'tokens_balance': FieldValue.increment(-5),
          'tickets_balance': FieldValue.increment(1),
        });
      });
      return true;
    } catch (e) {
      // In a real app, you might want to log this
      return false;
    }
  }

  /// Usa 1 ticket (para participar en un sorteo). Devuelve true si tuvo éxito.
  Future<bool> usarTicket() async {
    if (_uid.isEmpty) return false;
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('usuarios').doc(_uid);
        final snap = await transaction.get(docRef);
        if (!snap.exists) throw Exception('Usuario no encontrado');
        
        final data = snap.data() as Map<String, dynamic>;
        final int tickets = data['tickets_balance'] ?? 0;
        if (tickets < 1) throw Exception('No hay tickets disponibles');
        
        transaction.update(docRef, {
          'tickets_balance': FieldValue.increment(-1),
        });
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Suma una cantidad arbitraria de tickets (usado al comprar un producto que otorga tickets).
  Future<void> sumarTickets(int cantidad) async {
    if (_uid.isEmpty || cantidad <= 0) return;
    await _firestore.collection('usuarios').doc(_uid).update({
      'tickets_balance': FieldValue.increment(cantidad),
    });
  }

  /// Obtiene el saldo actual de tickets.
  Future<int> obtenerTicketBalance() async {
    if (_uid.isEmpty) return 0;
    final doc = await _firestore.collection('usuarios').doc(_uid).get();
    return doc.data()?['tickets_balance'] ?? 0;
  }

  /// Obtiene el saldo actual de tokens.
  Future<int> obtenerTokenBalance() async {
    if (_uid.isEmpty) return 0;
    final doc = await _firestore.collection('usuarios').doc(_uid).get();
    return doc.data()?['tokens_balance'] ?? 0;
  }
}