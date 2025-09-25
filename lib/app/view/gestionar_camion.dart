import 'package:flutter/material.dart';

class GestionarCamionesPage extends StatefulWidget {
  const GestionarCamionesPage({super.key});

  @override
  State<GestionarCamionesPage> createState() => _GestionarCamionesPageState();
}

class _GestionarCamionesPageState extends State<GestionarCamionesPage> {
  // Lista simulada de camiones
  final List<Map<String, dynamic>> _camiones = List.generate(23, (index) {
    return {
      'placa': 'ABC-${1000 + index}',
      'modelo': 'Modelo ${index + 1}',
      'estado': index % 2 == 0 ? 'Disponible' : 'En mantenimiento',
    };
  });

  // Controladores de búsqueda y paginación
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    // Filtrar por búsqueda
    List<Map<String, dynamic>> filtered = _camiones.where((camion) {
      return camion['placa'].toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          camion['modelo'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    void mostrarDetallesCamion(Map<String, dynamic> camion) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Detalles del Camión"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Placa: ${camion['placa']}"),
                Text("Modelo: ${camion['modelo']}"),
                Text("Marca: ${camion['marca'] ?? 'N/A'}"),
                Text("Capacidad Máx: ${camion['capacidad_max'] ?? 'N/A'}"),
                Text("Estado: ${camion['estado']}"), // 🔹 corregido
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            ],
          );
        },
      );
    }
      

    // Calcular paginación
    int totalPages = (filtered.length / _itemsPerPage).ceil();
    int start = _currentPage * _itemsPerPage;
    int end = start + _itemsPerPage;
    List<Map<String, dynamic>> paginated = filtered.sublist(
      start,
      end > filtered.length ? filtered.length : end,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Gestionar Camiones")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔎 Barra de búsqueda
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por placa o modelo...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 0; // Reinicia a la primera página al buscar
                });
              },
            ),
            const SizedBox(height: 20),

            // 📋 Lista de camiones
            Expanded(
              child: ListView.builder(
                itemCount: paginated.length,
                itemBuilder: (context, index) {
                  final camion = paginated[index];
                  bool disponible = camion['estado'] == 'Disponible';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: disponible ? Colors.green : Colors.red,
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        camion['placa'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(camion['modelo']),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'editar') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Editar camión ${camion['placa']}',
                                ),
                              ),
                            );
                          } else if (value == 'eliminar') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Eliminar camión ${camion['placa']}',
                                ),
                              ),
                            );
                          } else if (value == 'baja') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Dar de baja camión ${camion['placa']}',
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'eliminar',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Eliminar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'baja',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 8),
                                Text('Dar de baja'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => mostrarDetallesCamion(camion),
                    ),
                  );
                },
              ),
            ),

            // ⬅️➡️ Controles de paginación
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  Text(
                    'Página ${_currentPage + 1} de $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),

      // ➕ Botón flotante para añadir camión
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Añadir nuevo camión')));
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
    
  }
}
