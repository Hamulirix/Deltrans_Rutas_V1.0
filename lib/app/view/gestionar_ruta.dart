import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/gestionar_detalleruta.dart';


class GestionarRutasPage extends StatefulWidget {
  const GestionarRutasPage({super.key});

  @override
  State<GestionarRutasPage> createState() => _GestionarRutasPageState();
}

class _GestionarRutasPageState extends State<GestionarRutasPage> {
  // ====== Mock de datos ======
  final List<Map<String, dynamic>> _rutas = [
    {
      'id_ruta': 1,
      'fecha': DateTime.now(),
      'placa': 'TRK-123',
      'estado': true,
      'puntos': List.generate(50, (i) {
        return {
          'orden': i + 1,
          'direccion': 'Calle Ejemplo ${i + 1}',
          'latitud': -12.05 + i * 0.001,
          'longitud': -77.05 - i * 0.001,
        };
      }),
    },
    {
      'id_ruta': 2,
      'fecha': DateTime.now().add(const Duration(days: 1)),
      'placa': 'TRK-456',
      'estado': false,
      'puntos': List.generate(44, (i) {
        return {
          'orden': i + 1,
          'direccion': 'Av. Otra ${i + 1}',
          'latitud': -12.1 + i * 0.001,
          'longitud': -77.1 - i * 0.001,
        };
      }),
    },
  ];

  String _formateaFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    // Filtra solo las rutas con >= 45 puntos
    final rutasValidas =
        _rutas.where((r) => (r['puntos'] as List).length >= 45).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Rutas')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rutasValidas.length,
        itemBuilder: (context, index) {
          final ruta = rutasValidas[index];
          final idRuta = ruta['id_ruta'];
          final fecha = ruta['fecha'] as DateTime;
          final placa = ruta['placa'];
          final estado = ruta['estado'] as bool;
          final puntos = ruta['puntos'] as List<Map<String, dynamic>>;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: estado ? Colors.green : Colors.grey,
                child: const Icon(Icons.route, color: Colors.white),
              ),
              title: Text(
                'Fecha: ${_formateaFecha(fecha)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Camión: $placa • Puntos: ${puntos.length}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Editar ruta #$idRuta')),
                  );
                },
              ),
              // 👉 Aquí abrimos la otra pantalla con Navigator.push
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RutaDetallePage(
                      idRuta: idRuta,
                      fecha: fecha,
                      placa: placa,
                      estado: estado,
                      puntos: puntos,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
