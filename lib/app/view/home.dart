import 'package:flutter/material.dart';
import 'inicio_conductor.dart';
import 'inicio_gerente.dart';
import 'gestionar_page.dart';
import 'perfil_page.dart';

class Home extends StatefulWidget {
  final String nombre;
  final String rol; // "conductor" o "gerente"

  const Home({super.key, required this.nombre, required this.rol});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      // 👇 Aquí decides qué inicio mostrar según el rol
      widget.rol == "conductor"
          ? InicioConductor(nombre: widget.nombre)
          : InicioGerente(nombre: widget.nombre),
      const GestionarPage(),
      PerfilPage(nombre: widget.nombre),
    ];

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Inicio",
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: "Gestionar",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Perfil",
          ),
        ],
      ),
      body: pages[currentPageIndex],
    );
  }
}
