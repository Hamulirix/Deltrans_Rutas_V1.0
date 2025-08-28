import 'package:flutter/material.dart';

class GestionarPage extends StatelessWidget {
  const GestionarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Aquí podrás gestionar tus viajes 📦",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
