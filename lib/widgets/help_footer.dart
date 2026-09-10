import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';

/// Footer de ayuda que copia el número de WhatsApp al portapapeles.
class HelpFooter extends StatelessWidget {
  const HelpFooter({super.key});

  static const String _telefono = '5492494690672';

  void _copiarNumero(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _telefono));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '📋 Número copiado',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          const Text(
            '¿Necesitás ayuda?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _copiarNumero(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💬', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Contáctanos por WhatsApp',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.green[600],
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
