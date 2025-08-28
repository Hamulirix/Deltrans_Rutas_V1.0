// home_gerente.dart
import 'package:flutter/material.dart';

class HomeGerente extends StatelessWidget {
  final String nombre;
  const HomeGerente({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Bienvenido $nombre - Gerente"),
      ),
    );
  }
}
