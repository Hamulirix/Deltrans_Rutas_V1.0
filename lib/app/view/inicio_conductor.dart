import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/mostrar_ruta_conductor.dart';

class InicioConductor extends StatelessWidget {
  final String nombre;
  final String? placa;

  const InicioConductor({
    super.key,
    required this.nombre,
    this.placa,
  });

String _fechaHoy() {
  // Hora actual en UTC
  final utcNow = DateTime.now().toUtc();
  // Perú es UTC-5
  final peruTime = utcNow.add(const Duration(hours: -5));
  final d = peruTime.day.toString().padLeft(2, '0');
  final m = peruTime.month.toString().padLeft(2, '0');
  final y = peruTime.year.toString();
  return '$d/$m/$y';
}

  @override
  Widget build(BuildContext context) {
    final placaText = placa == null || placa!.isEmpty ? '— sin camión —' : placa!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header...
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
              Text("Placa: $placaText", style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 30),
          const Text("Fecha", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_fechaHoy(), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 40),
          Center(
            child: ElevatedButton(
              onPressed: () {
                if (placa == null || placa!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No tienes camión asignado.")),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MostrarRutaConductorPage(
                      placa: placa!,                 // la que muestras arriba
                      fecha: DateTime.now(),         // hoy
                    ),
                  ),
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
