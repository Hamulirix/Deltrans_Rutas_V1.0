import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/gestionar_page.dart';
import 'package:flutter_application_1/app/view/inicio_conductor.dart';
import 'package:flutter_application_1/app/view/inicio_gerente.dart';
import 'package:flutter_application_1/app/view/perfil_page.dart';

class Home extends StatefulWidget {
  final String nombre;
  final String rol;          // "gerente" | "conductor"
  final String? placaCamion; // solo para conductor

  const Home({
    super.key,
    required this.nombre,
    required this.rol,
    this.placaCamion,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isConductor = widget.rol == "conductor";

    // Páginas según rol
    final pages = isConductor
        ? <Widget>[
            InicioConductor(nombre: widget.nombre, placa: widget.placaCamion),
            PerfilPage(nombre: widget.nombre),
          ]
        : <Widget>[
            InicioGerente(nombre: widget.nombre),
            const GestionarPage(),
            PerfilPage(nombre: widget.nombre),
          ];

    // Títulos según rol
    final pageTitles = isConductor
        ? const ["Inicio", "Perfil"]
        : const ["Inicio", "Gestionar", "Perfil"];

    // Destinos de navegación según rol
    final destinations = isConductor
        ? <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.grey[600]),
              selectedIcon:
                  Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
              label: "Inicio",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Colors.grey[600]),
              selectedIcon:
                  Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
              label: "Perfil",
            ),
          ]
        : <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.grey[600]),
              selectedIcon:
                  Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
              label: "Inicio",
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline, color: Colors.grey[600]),
              selectedIcon:
                  Icon(Icons.work, color: Theme.of(context).colorScheme.primary),
              label: "Gestionar",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Colors.grey[600]),
              selectedIcon:
                  Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
              label: "Perfil",
            ),
          ];

    // Evita desbordes si cambió la cantidad de tabs
    if (currentPageIndex >= pages.length) {
      currentPageIndex = 0;
    }

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
            setState(() => currentPageIndex = index);
          },
          destinations: destinations,
        ),
      ),
    );
  }
}
