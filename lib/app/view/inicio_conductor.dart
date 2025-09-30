// lib/app/view/inicio_conductor.dart
import 'package:flutter/material.dart';

class InicioConductor extends StatelessWidget {
  final String nombre;
  const InicioConductor({super.key, required this.nombre});

  String _fechaHoy() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Bienvenido de nuevo", style: TextStyle(fontSize: 16)),
                  Text(nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const Text("Camión N° 2", style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 30),
          const Text("Fecha", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_fechaHoy(), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 40),
          Center(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ruta asignada en construcción 🚚")),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Ver ruta asignada", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
