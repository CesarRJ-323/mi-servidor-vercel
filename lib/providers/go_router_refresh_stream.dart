import 'dart:async';
import 'package:flutter/foundation.dart';

/// Conecta un Stream de Firebase Auth con el refresh del GoRouter.
/// Permite que los guards de ruta reaccionen al login/logout en tiempo real.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
