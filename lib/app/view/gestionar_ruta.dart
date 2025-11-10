import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/agregar_ruta.dart';
import 'package:flutter_application_1/app/view/editar_ruta.dart';
import 'package:flutter_application_1/app/view/mapa_ubicacion.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';

class GestionarRutasPage extends StatefulWidget {
  const GestionarRutasPage({super.key});

  @override
  State<GestionarRutasPage> createState() => _GestionarRutasPageState();
}

class _GestionarRutasPageState extends State<GestionarRutasPage> {
  final _api = ApiService();
  List<RutaResumen> _filtradas = [];
  bool _loading = true;

  // Paginación
  int _paginaActual = 1;
  final int _porPagina = 6;

  // Filtros
  DateTime? _fechaSeleccionada;
  List<Camion> _camiones = [];
  Camion? _camionSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCamionesYFiltros();
  }

  Future<void> _cargarCamionesYFiltros() async {
    try {
      setState(() => _loading = true);
      final camiones = await _api.listarCamiones();
      _camiones = camiones.where((c) => c.disponible).toList();
      await _cargarRutas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando camiones: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarRutas() async {
    try {
      setState(() => _loading = true);
      final fechaParam =
          _fechaSeleccionada?.toIso8601String().split('T').first ?? '';
      final idCamion = _camionSeleccionado?.idCamion;

      final lista = await _api.listarRutas(
        fecha: fechaParam.isEmpty ? null : fechaParam,
        idCamion: idCamion,
      );

      if (!mounted) return;
      setState(() {
        _filtradas = lista;
        _paginaActual = 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando rutas: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mostrarSelectorFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (seleccionada != null) {
      setState(() => _fechaSeleccionada = seleccionada);
      _cargarRutas();
    }
  }

  String _formatearFecha(DateTime? f) {
    if (f == null) return '';
    return "${f.day.toString().padLeft(2, '0')}-"
        "${f.month.toString().padLeft(2, '0')}-"
        "${f.year}";
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearRutaMapaPage()),
          );
          if (resultado == true && mounted) _cargarRutas();
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🧭 Filtros (camión y fecha) en columnas
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: "Limpiar filtros",
                          onPressed: () {
                            setState(() {
                              _camionSeleccionado = null;
                              _fechaSeleccionada = null;
                            });
                            _cargarRutas();
                          },
                        ),
                      ),

                      DropdownButtonFormField<Camion>(
                        value: _camionSeleccionado,
                        items: _camiones.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              "${c.placa} • ${c.marca}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (c) {
                          setState(() => _camionSeleccionado = c);
                          _cargarRutas();
                        },
                        decoration: const InputDecoration(
                          labelText: "Filtrar por camión",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _mostrarSelectorFecha,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Filtrar por fecha",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _formatearFecha(_fechaSeleccionada),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                ),

                // 📋 Lista de rutas
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
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditarRutaMapaPage(
                                              idRuta: ruta.idRuta,
                                            ),
                                          ),
                                        );
                                        if (mounted) await _cargarRutas();
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
                                  onTap: () async {
                                    try {
                                      final puntosRuta = await _api
                                          .listarPuntosDeRuta(ruta.idRuta);

                                      if (puntosRuta.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Esta ruta no tiene puntos registrados.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final puntos = puntosRuta
                                          .map((p) => LatLng(p.lat, p.lng))
                                          .toList();

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MapaUbicacionPage(
                                            titulo:
                                                'Ruta ${ruta.placa ?? ""} (${ruta.fecha ?? ""})',
                                            puntos: puntos,
                                            descripcion:
                                                'Total de puntos: ${puntos.length}',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content:
                                            Text('Error al mostrar mapa: $e'),
                                      ));
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),

                // ⏩ Paginación
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
