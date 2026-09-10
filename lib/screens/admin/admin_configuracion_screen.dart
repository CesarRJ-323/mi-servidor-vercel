import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminConfiguracionScreen extends ConsumerWidget {
  const AdminConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('configuracion').doc('pago_alternativo');

    // Controllers for the fields
    final aliasCtrl = TextEditingController();
    final instruccionesCtrl = TextEditingController();
    final activoCtrl = ValueNotifier<bool>(false);

    // Fetch current config on init
    void loadConfig() async {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          aliasCtrl.text = data['aliasPago'] ?? '';
          instruccionesCtrl.text = data['instrucciones'] ?? '';
          activoCtrl.value = data['activo'] ?? false;
        }
      }
    }

    // Save config
    void saveConfig() async {
      await docRef.set({
        'aliasPago': aliasCtrl.text.trim(),
        'instrucciones': instruccionesCtrl.text.trim(),
        'activo': activoCtrl.value,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    // Initialize
    WidgetsBinding.instance.addPostFrameCallback((_) => loadConfig());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Pago Alternativo'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'Alias de pago (ej. Leorod.arg)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: instruccionesCtrl,
              decoration: const InputDecoration(
                labelText: 'Instrucciones para el usuario',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: activoCtrl,
              builder: (context, value, child) {
                return SwitchListTile(
                  title: const Text('Activar pago alternativo'),
                  value: value,
                  onChanged: (bool val) {
                    activoCtrl.value = val;
                  },
                  secondary: const Icon(Icons.toggle_on),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Guardar Configuración',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}