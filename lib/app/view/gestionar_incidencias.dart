import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/mapa_ubicacion.dart';
import '../services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GestionarIncidenciasPage extends StatefulWidget {
  const GestionarIncidenciasPage({super.key});

  @override
  State<GestionarIncidenciasPage> createState() =>
      _GestionarIncidenciasPageState();
}

class _GestionarIncidenciasPageState extends State<GestionarIncidenciasPage> {
  final _api = ApiService();

  List<Desvio> _desvios = [];
  bool _loading = false;
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _cargarDesvios();
  }

  Future<void> _cargarDesvios() async {
    setState(() => _loading = true);
    try {
      final data = await _api.listarDesvios();
      setState(() {
        _desvios = data;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar incidencias: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Desvio> _filtrar(List<Desvio> base) {
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((d) {
      final idMatch = d.idDesvio.toString().contains(q);
      final motivoMatch = d.motivo.toLowerCase().contains(q);
      return idMatch || motivoMatch;
    }).toList();
  }

  Future<void> _confirmarBaja(Desvio d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dar de baja'),
        content: Text('¿Dar de baja la incidencia #${d.idDesvio}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final msg = await _api.darBajaDesvio(d.idDesvio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _cargarDesvios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmarEliminar(Desvio d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar incidencia'),
        content: Text(
          '¿Eliminar permanentemente la incidencia #${d.idDesvio}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final msg = await _api.eliminarDesvio(d.idDesvio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _cargarDesvios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrar(_desvios);
    final totalPages = (filtrados.length / _itemsPerPage).ceil().clamp(1, 999);
    final start = (_currentPage * _itemsPerPage).clamp(0, filtrados.length);
    final end = (start + _itemsPerPage).clamp(0, filtrados.length);
    final pageItems = filtrados.sublist(start, end);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Incidencias')),
      body: RefreshIndicator(
        onRefresh: _cargarDesvios,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por motivo...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() {
                  _searchQuery = value;
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (pageItems.isEmpty
                          ? const Center(child: Text('Sin resultados'))
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: pageItems.length,
                              itemBuilder: (context, index) {
                                final d = pageItems[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: d.estado == 'Activo'
                                          ? Colors.orange
                                          : Colors.grey,
                                      child: const Icon(
                                        Icons.warning,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      'Incidencia #${d.idDesvio}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${d.motivo}\n(${d.estado})',
                                    ),
                                    isThreeLine: true,
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'baja') {
                                          _confirmarBaja(d);
                                        } else if (value == 'eliminar') {
                                          _confirmarEliminar(d);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
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
                                        PopupMenuItem(
                                          value: 'eliminar',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Eliminar'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MapaUbicacionPage(
                                            titulo: 'Incidencia #${d.idDesvio}',
                                            puntos: [LatLng(d.lat, d.lng)],
                                            descripcion: d.motivo,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            )),
              ),

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
    );
  }
}
