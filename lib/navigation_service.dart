import 'package:flutter/material.dart';

/// Global navigator key para navegación desde callbacks que no tienen BuildContext.
/// Se usa principalmente para navegar cuando se toca una notificación push.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
