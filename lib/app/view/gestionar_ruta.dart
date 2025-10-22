import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/editar_ruta.dart';
import '../services/api_service.dart';

class GestionarRutasPage extends StatefulWidget {
  const GestionarRutasPage({super.key});

  @override
  State<GestionarRutasPage> createState() => _GestionarRutasPageState();
}

class _GestionarRutasPageState extends State<GestionarRutasPage> {
  final _api = ApiService();
  List<RutaResumen> _rutas = [];
  List<RutaResumen> _filtradas = [];
  bool _loading = true;

  // Paginación
  int _paginaActual = 1;
  final int _porPagina = 6; // cantidad de rutas por página

  // Búsqueda
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRutas();
  }

  Future<void> _cargarRutas() async {
    try {
      setState(() => _loading = true);
      final lista = await _api.listarRutas();
      setState(() {
        _rutas = lista;
        _filtradas = lista;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando rutas: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filtrar(String query) {
    query = query.toLowerCase();
    setState(() {
      _paginaActual = 1; // volver al inicio
      if (query.isEmpty) {
        _filtradas = _rutas;
      } else {
        _filtradas = _rutas.where((r) {
          final placa = r.placa?.toLowerCase() ?? '';
          final fecha = r.fecha?.toLowerCase() ?? '';
          return placa.contains(query) || fecha.contains(query);
        }).toList();
      }
    });
  }

  void _confirmarEliminacion(BuildContext context, RutaResumen ruta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar ruta?'),
        content: Text('¿Estás seguro de eliminar la ruta del ${ruta.fecha}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final msg = await _api.eliminarRuta(ruta.idRuta);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        _cargarRutas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPaginas = (_filtradas.length / _porPagina)
        .ceil()
        .clamp(1, double.infinity)
        .toInt();

    final inicio = (_paginaActual - 1) * _porPagina;
    final fin = (_paginaActual * _porPagina).clamp(0, _filtradas.length);
    final paginaActualRutas = _filtradas.sublist(
      inicio,
      fin > _filtradas.length ? _filtradas.length : fin,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Rutas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Campo de búsqueda
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _busquedaController,
                    onChanged: _filtrar,
                    decoration: InputDecoration(
                      hintText: 'Buscar por placa o fecha...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busquedaController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _busquedaController.clear();
                                _filtrar('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _filtradas.isEmpty
                      ? const Center(child: Text('No hay rutas registradas'))
                      : RefreshIndicator(
                          onRefresh: _cargarRutas,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: paginaActualRutas.length,
                            itemBuilder: (context, index) {
                              final ruta = paginaActualRutas[index];
                              final esActiva = ruta.estado == 1;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: esActiva
                                        ? Colors.green
                                        : Colors.grey,
                                    child: const Icon(
                                      Icons.route,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    'Fecha: ${ruta.fecha ?? "—"}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Camión: ${ruta.placa ?? "—"}\nPuntos: ${ruta.nPuntos}',
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'editar') {
                                        // 👇 Espera el resultado al cerrar la pantalla de edición
                                        final actualizado =
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EditarRutaMapaPage(
                                                      idRuta: ruta.idRuta,
                                                    ),
                                              ),
                                            );

                                        // 👇 Si devolvió true, recarga las rutas
                                        if (actualizado == true && mounted) {
                                          await _cargarRutas();
                                          if (!mounted)
                                            return; // doble seguridad
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Ruta actualizada correctamente',
                                              ),
                                            ),
                                          );
                                        }
                                      } else if (value == 'eliminar') {
                                        _confirmarEliminacion(context, ruta);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'editar',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'eliminar',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Eliminar'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),

                // Controles de paginación
                if (_filtradas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Página $_paginaActual de $totalPaginas'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: _paginaActual > 1
                                  ? () => setState(() => _paginaActual--)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _paginaActual < totalPaginas
                                  ? () => setState(() => _paginaActual++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
