// home_conductor.dart
import 'package:flutter/material.dart';

class HomeConductor extends StatefulWidget {
  final String nombre;
  const HomeConductor({super.key, required this.nombre});

  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.directions_car),
            icon: Icon(Icons.directions_car_outlined),
            label: 'Gestionar',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person),
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
      body: <Widget>[
        /// Página de Inicio
        Center(
          child: Text(
            "Bienvenido ${widget.nombre} - Conductor",
            style: theme.textTheme.titleLarge,
          ),
        ),

        /// Página de Gestionar
        Center(
          child: Text(
            "Aquí gestionas tus entregas/rutas",
            style: theme.textTheme.titleLarge,
          ),
        ),

        /// Página de Perfil
        Center(
          child: Text(
            "Perfil del Conductor: ${widget.nombre}",
            style: theme.textTheme.titleLarge,
          ),
        ),
      ][currentPageIndex],
    );
  }
}
