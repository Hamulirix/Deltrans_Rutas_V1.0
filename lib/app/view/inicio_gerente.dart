import 'package:flutter/material.dart';

class InicioGerente extends StatelessWidget {
  final String nombre;
  const InicioGerente({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Bienvenido $nombre 👔 (Gerente)",
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
