import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'forms.dart';

class GestionarUsuariosPage extends StatefulWidget {
  const GestionarUsuariosPage({super.key});

  @override
  State<GestionarUsuariosPage> createState() => _GestionarUsuariosPageState();
}

class _GestionarUsuariosPageState extends State<GestionarUsuariosPage> {
  final _api = ApiService();

  // Estado
  List<Usuario> _usuarios = [];
  bool _loading = false;
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _loading = true);
    try {
      final data = await _api.listarUsuarios();
      setState(() {
        _usuarios = data;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar usuarios: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Usuario> _filtrar(List<Usuario> base) {
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((u) {
      return u.nombres.toLowerCase().contains(q) ||
          u.apellidos.toLowerCase().contains(q) ||
          u.dni.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.tipoTrabajador.toLowerCase().contains(q);
    }).toList();
  }

  void _verDetalles(Usuario u) {
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
                _detalle('Nombres', u.nombres),
                _detalle('Apellidos', u.apellidos),
                _detalle('DNI', u.dni),
                _detalle('Tipo de trabajador', u.tipoTrabajador),
                _detalle('Usuario (username)', u.username),
                const SizedBox(height: 8),
                
                const SizedBox(height: 8),
                _detalle('Estado', u.estado),
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

  Widget _detalle(String label, String value) => Padding(
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

  Future<void> _confirmarEliminar(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
            '¿Seguro que deseas eliminar o dar de baja a @${u.username}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final msg = await _api.eliminarUsuario(u.idUsuario);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _editarUsuario(Usuario u) async {
    // No obtenemos id_tipo_trabajador en listar_usuarios (solo el nombre),
    // así que abrimos el formulario con lo disponible.
    // El form obliga a seleccionar o ingresar el tipo.
    final initial = UsuarioUpdateDto(
      nombres: u.nombres,
      apellidos: u.apellidos,
      dni: u.dni,
      idTipoTrabajador: 0, // el usuario deberá elegirlo/ingresarlo
      username: u.username,
      idCamion: null,
      estado: u.estaActivo,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsuarioFormPage(
          usuarioId: u.idUsuario,
          initial: initial,
          // Si tienes un catálogo: pásalo aquí para dropdown:
          // tiposTrabajador: {1: 'Conductor', 2: 'Gerente', 3: 'Operario'},
        ),
      ),
    );
    // Al volver, refrescamos
    if (mounted) _cargarUsuarios();
  }

  void _crearUsuario() async {
    // Tu backend actual no tiene endpoint de creación en el snippet.
    // Aún así abrimos el form para capturar datos (usa onSubmit si quieres guardarlo por otro flujo).
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UsuarioFormPage(),
      ),
    );
    if (mounted) _cargarUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrar(_usuarios);
    final totalPages = (filtrados.length / _itemsPerPage).ceil().clamp(1, 999);
    final start = (_currentPage * _itemsPerPage).clamp(0, filtrados.length);
    final end = (start + _itemsPerPage).clamp(0, filtrados.length);
    final pageItems = filtrados.sublist(start, end);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Usuarios')),
      body: RefreshIndicator(
        onRefresh: _cargarUsuarios,
        child: Padding(
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (pageItems.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: pageItems.length,
                            itemBuilder: (context, index) {
                              final u = pageItems[index];
                              final activo = u.estaActivo;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        activo ? Colors.green : Colors.grey,
                                    child: const Icon(Icons.person,
                                        color: Colors.white),
                                  ),
                                  title: Text(
                                    '${u.nombres} ${u.apellidos}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'DNI: ${u.dni}  •  ${u.tipoTrabajador}  •  @${u.username}',
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'editar') {
                                        _editarUsuario(u);
                                      } else if (value == 'eliminar') {
                                        _confirmarEliminar(u);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'editar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                size: 18, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'eliminar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Eliminar / Dar de baja'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _verDetalles(u),
                                ),
                              );
                            },
                          )),
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
      ),

      // ➕ Botón flotante para crear usuario
      floatingActionButton: FloatingActionButton(
        onPressed: _crearUsuario,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}
