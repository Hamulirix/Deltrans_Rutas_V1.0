import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/gestionar_camion.dart';
import 'package:flutter_application_1/app/view/gestionar_ruta.dart';
import 'package:flutter_application_1/app/view/gestionar_usuario.dart';

class GestionarPage extends StatelessWidget {
  const GestionarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 1,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 3,
                  children: [
                    _buildGestionItem(
                      context,
                      'Usuarios',
                      Icons.people,
                      Colors.blue,
                      () {
                       Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GestionarUsuariosPage(),
                          ),
                        );
                      },
                    ),
                    _buildGestionItem(
                      context,
                      'Camiones',
                      Icons.local_shipping,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GestionarCamionesPage(),
                          ),
                        );
                      },
                    ), 
                    _buildGestionItem(
                      context,
                      'Rutas',
                      Icons.route,
                      Colors.orange,
                      () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GestionarRutasPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestionItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
