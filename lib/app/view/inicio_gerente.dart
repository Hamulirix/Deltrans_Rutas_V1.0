import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/asignar_rutas.dart';
import 'package:flutter_application_1/app/view/optimizar_rutas.dart';
import 'package:flutter_application_1/app/view/reportes_page.dart';

class InicioGerente extends StatelessWidget {
  final String nombre;
  const InicioGerente({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con logo y bienvenida
              _buildHeader(context),
              const SizedBox(height: 30),

              // Tarjeta de estadísticas
              _buildStatsCard(context),
              const SizedBox(height: 30),

              // Sección de acciones rápidas (solo móvil)
              _buildQuickActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Aplicación Deltrans",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Bienvenido de nuevo",
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 5),
        Text(
          "$nombre - Gerente",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xff171a1f),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Número de rutas optimizadas",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 15),
            Text(
              "25",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Acciones rápidas",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 15),
        _buildMobileGrid(context),
      ],
    );
  }

  Widget _buildMobileGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: [
        _buildActionButton(
          context,
          "Optimizar rutas",
          Icons.trending_up,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OptimizarRutasPage()),
            );
          },
        ),
        _buildActionButton(
          context,
          "Asignar rutas",
          Icons.assignment_turned_in,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AsignarRutasPage()),
            );
          },
        ),
        _buildActionButton(
          context,
          "Reportes",
          Icons.assessment,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportesPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
