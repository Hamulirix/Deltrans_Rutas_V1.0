import 'package:flutter/material.dart';

class InicioConductor extends StatelessWidget {
  final String nombre;
  const InicioConductor({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Bienvenido $nombre 🚛 (Conductor)",
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
