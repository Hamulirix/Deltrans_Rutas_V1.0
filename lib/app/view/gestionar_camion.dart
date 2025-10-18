import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'forms.dart';

class GestionarCamionesPage extends StatefulWidget {
  const GestionarCamionesPage({super.key});

  @override
  State<GestionarCamionesPage> createState() => _GestionarCamionesPageState();
}

class _GestionarCamionesPageState extends State<GestionarCamionesPage> {
  final _api = ApiService();

  // Estado
  List<Camion> _camiones = [];
  bool _loading = false;
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
  }

  Future<void> _cargarCamiones() async {
    setState(() => _loading = true);
    try {
      final data = await _api.listarCamiones();
      setState(() {
        _camiones = data;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar camiones: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Camion> _filtrar(List<Camion> base) {
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((c) {
      return c.placa.toLowerCase().contains(q) ||
          c.modelo.toLowerCase().contains(q) ||
          c.marca.toLowerCase().contains(q);
    }).toList();
  }

  void _mostrarDetallesCamion(Camion c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalles del Camión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detalle('Placa', c.placa),
            _detalle('Modelo', c.modelo),
            _detalle('Marca', c.marca),
            _detalle('Capacidad Máx', '${c.capacidadMax}'),
            _detalle('Estado', c.estado),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _detalle(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Future<void> _confirmarEliminar(Camion c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar camión'),
        content: Text(
          '¿Eliminar el camión ${c.placa}?\n'
          'Si está asignado a un trabajador o ruta, el backend lo dará de baja automáticamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final msg = await _api.eliminarCamion(c.idCamion);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _cargarCamiones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _editarCamion(Camion c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CamionFormPage(
          initial: c,
          onUpdate: (dto) async {
            try {
              final msg = await _api.actualizarCamion(c.idCamion, dto);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              Navigator.of(context).maybePop();
              await _cargarCamiones();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
        ),
      ),
    );
  }

  void _crearCamion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CamionFormPage(
          onCreate: (dto) async {
            try {
              final res = await _api.crearCamion(dto);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Camión #${res['id_camion']} (${res['placa']}) creado')),
              );
              Navigator.of(context).maybePop();
              await _cargarCamiones();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrar(_camiones);
    final totalPages = (filtrados.length / _itemsPerPage).ceil().clamp(1, 999);
    final start = (_currentPage * _itemsPerPage).clamp(0, filtrados.length);
    final end = (start + _itemsPerPage).clamp(0, filtrados.length);
    final pageItems = filtrados.sublist(start, end);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Camiones')),
      body: RefreshIndicator(
        onRefresh: _cargarCamiones,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 🔎 Búsqueda
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por placa, modelo o marca...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              final c = pageItems[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: c.disponible ? Colors.green : Colors.grey,
                                    child: const Icon(Icons.local_shipping, color: Colors.white),
                                  ),
                                  title: Text(c.placa, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${c.marca} • ${c.modelo} • Cap: ${c.capacidadMax}'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'editar') {
                                        _editarCamion(c);
                                      } else if (value == 'eliminar') {
                                        _confirmarEliminar(c);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'editar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'eliminar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Eliminar'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _mostrarDetallesCamion(c),
                                ),
                              );
                            },
                          )),
              ),

              // ⬅️➡️ Paginación
              if (totalPages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    ),
                    Text('Página ${_currentPage + 1} de $totalPages',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed:
                          _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),

      // ➕ FAB crear
      floatingActionButton: FloatingActionButton(
        onPressed: _crearCamion,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
