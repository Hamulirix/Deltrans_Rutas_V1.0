import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/gestionar_page.dart';
import 'package:flutter_application_1/app/view/inicio_conductor.dart';
import 'package:flutter_application_1/app/view/inicio_gerente.dart';
import 'package:flutter_application_1/app/view/perfil_page.dart';

class Home extends StatefulWidget {
  final String nombre;
  final String rol;

  const Home({super.key, required this.nombre, required this.rol});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 0;

  // Títulos para cada página
  final List<String> pageTitles = const [
    "Inicio",
    "Gestionar",
    "Perfil"
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      widget.rol == "conductor"
          ? InicioConductor(nombre: widget.nombre)
          : InicioGerente(nombre: widget.nombre),
      const GestionarPage(),
      PerfilPage(nombre: widget.nombre),
    ];

    // Solo móvil: usar NavigationBar inferior
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff171a1f),
        elevation: 1,
        title: Text(
          pageTitles[currentPageIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xff171a1f),
          ),
        ),
      ),
      body: pages[currentPageIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: currentPageIndex,
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
                color: Colors.grey[600],
              ),
              selectedIcon: Icon(
                Icons.home,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: "Inicio",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.work_outline,
                color: Colors.grey[600],
              ),
              selectedIcon: Icon(
                Icons.work,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: "Gestionar",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: Colors.grey[600],
              ),
              selectedIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: "Perfil",
            ),
          ],
        ),
      ),
    );
  }
}
