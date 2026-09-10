import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delivery_app_v2/widgets/sorteo_section.dart';

/// "Ver sorteos" — muestra los sorteos ACTIVOS para participar directamente.
/// Reemplaza a SorteosHistorialScreen en la ruta /sorteos, que confundió al
/// usuario al mostrar el historial (sorteos terminados) en lugar de los
/// sorteos activos.
class SorteosActivosScreen extends ConsumerWidget {
  const SorteosActivosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sorteos'),
        backgroundColor: const Color(0xFF2A0800),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const SorteoSection(),
        ),
      ),
    );
  }
}