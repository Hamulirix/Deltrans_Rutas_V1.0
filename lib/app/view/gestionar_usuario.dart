import 'package:flutter/material.dart';

class GestionarUsuariosPage extends StatefulWidget {
  const GestionarUsuariosPage({super.key});

  @override
  State<GestionarUsuariosPage> createState() => _GestionarUsuariosPageState();
}

class _GestionarUsuariosPageState extends State<GestionarUsuariosPage> {
  // ===== Mock: resultado de un JOIN entre trabajador, tipo_trabajador y usuario =====
  // Campos requeridos: nombres, apellidos, dni, nombre_tipo, username, password_hash (+ estado)
  final List<Map<String, dynamic>> _usuarios = List.generate(27, (i) {
    final esPar = i % 2 == 0;
    return {
      'nombres': 'Nombre $i',
      'apellidos': 'Apellido $i',
      'dni': (70000000 + i).toString(),
      'nombre_tipo': (i % 3 == 0)
          ? 'Conductor'
          : (i % 3 == 1)
              ? 'Gerente'
              : 'Operario',
      'username': 'user$i',
      'password_hash':
          'pbkdf2_sha256\$600000\$salt$i\$abcdefghijklmnopqrstuvxyz$i', // ejemplo
      'estado': esPar, // true = activo, false = inactivo
    };
  });

  // ===== Control de búsqueda y paginación =====
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  // ===== Helpers =====
  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> base) {
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((u) {
      return (u['nombres'] as String).toLowerCase().contains(q) ||
          (u['apellidos'] as String).toLowerCase().contains(q) ||
          (u['dni'] as String).toLowerCase().contains(q) ||
          (u['username'] as String).toLowerCase().contains(q) ||
          (u['nombre_tipo'] as String).toLowerCase().contains(q);
    }).toList();
  }

  void _mostrarDetallesUsuario(Map<String, dynamic> u) {
    bool mostrarHash = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSB) {
          return AlertDialog(
            title: const Text('Detalles del Usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalle('Nombres', u['nombres']),
                _detalle('Apellidos', u['apellidos']),
                _detalle('DNI', u['dni']),
                _detalle('Tipo de trabajador', u['nombre_tipo']),
                _detalle('Usuario (username)', u['username']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mostrarHash
                            ? 'Hash: ${u['password_hash']}'
                            : 'Hash: ••••••••••••••••••••••••••••',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      tooltip: mostrarHash ? 'Ocultar hash' : 'Mostrar hash',
                      onPressed: () => setSB(() => mostrarHash = !mostrarHash),
                      icon: Icon(
                        mostrarHash ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _detalle('Estado', (u['estado'] as bool) ? 'Activo' : 'Inactivo'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _detalle(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrar(_usuarios);

    // Paginación
    final totalPages = (filtrados.length / _itemsPerPage).ceil().clamp(1, 999);
    final start = (_currentPage * _itemsPerPage).clamp(0, filtrados.length);
    final end = (start + _itemsPerPage).clamp(0, filtrados.length);
    final pageItems = filtrados.sublist(start, end);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Usuarios')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔎 Búsqueda
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombres, apellidos, DNI o usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 0;
                });
              },
            ),
            const SizedBox(height: 16),

            // 📋 Listado
            Expanded(
              child: ListView.builder(
                itemCount: pageItems.length,
                itemBuilder: (context, index) {
                  final u = pageItems[index];
                  final activo = u['estado'] as bool;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: activo ? Colors.green : Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        '${u['nombres']} ${u['apellidos']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'DNI: ${u['dni']}  •  ${u['nombre_tipo']}  •  @${u['username']}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'editar') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Editar usuario @${u['username']}',
                                ),
                              ),
                            );
                          } else if (value == 'eliminar') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Eliminar usuario @${u['username']}',
                                ),
                              ),
                            );
                          } else if (value == 'toggle') {
                            setState(() => u['estado'] = !(u['estado'] as bool));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  (u['estado'] as bool)
                                      ? 'Usuario activado'
                                      : 'Usuario desactivado',
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
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  (activo)
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(activo ? 'Desactivar' : 'Activar'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _mostrarDetallesUsuario(u),
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

      // ➕ Botón flotante para crear usuario
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crear nuevo usuario')),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}
