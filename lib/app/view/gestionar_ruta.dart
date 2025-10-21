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
  bool _loading = true;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Rutas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rutas.isEmpty
          ? const Center(child: Text('No hay rutas registradas'))
          : RefreshIndicator(
              onRefresh: _cargarRutas,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _rutas.length,
                itemBuilder: (context, index) {
                  final ruta = _rutas[index];
                  final esActiva = ruta.estado == 1;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: esActiva ? Colors.green : Colors.grey,
                        child: const Icon(Icons.route, color: Colors.white),
                      ),
                      title: Text(
                        'Fecha: ${ruta.fecha ?? "—"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Camión: ${ruta.placa} \nPuntos: ${ruta.nPuntos}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'editar') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditarRutaMapaPage(idRuta: ruta.idRuta),
                              ),
                            );
                          } else if (value == 'eliminar') {
                            _confirmarEliminacion(context, ruta);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: const [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'eliminar',
                            child: Row(
                              children: const [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Eliminar'),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),

                      onTap: null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
