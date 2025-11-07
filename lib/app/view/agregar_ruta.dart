import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';
import 'buscar_cliente.dart';

class CrearRutaMapaPage extends StatefulWidget {
  const CrearRutaMapaPage({super.key});

  @override
  State<CrearRutaMapaPage> createState() => _CrearRutaMapaPageState();
}

class _CrearRutaMapaPageState extends State<CrearRutaMapaPage> {
  final _api = ApiService();
  final Set<Marker> _marcadores = {};
  GoogleMapController? _mapController;

  DateTime? _fechaSeleccionada;
  bool _modoAgregar = false;
  Marker? _marcadorTemporal;
  List<Map<String, dynamic>> _puntos = [];

  List<Camion> _camiones = [];
  Camion? _camionSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
  }

  Future<void> _cargarCamiones() async {
    try {
      final lista = await _api.listarCamiones();
      if (!mounted) return;
      setState(() {
        _camiones = lista
            .where((c) => c.disponible)
            .toList(); // solo disponibles
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error cargando camiones: $e")));
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ============================
  // FECHA
  // ============================
  void _mostrarSelectorFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (seleccionada != null) {
      setState(() => _fechaSeleccionada = seleccionada);
    }
  }

  String _formatearFecha(DateTime? f) {
    if (f == null) return '';
    return "${f.day.toString().padLeft(2, '0')}-"
        "${f.month.toString().padLeft(2, '0')}-"
        "${f.year}";
  }

  // ============================
  // AGREGAR PUNTO
  // ============================
  void _toggleModoAgregar() {
    setState(() {
      _modoAgregar = !_modoAgregar;
      _marcadorTemporal = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _modoAgregar
              ? 'Toca el mapa para agregar un punto (cliente).'
              : 'Modo agregar cancelado.',
        ),
      ),
    );
  }

  Future<void> _onMapTap(LatLng pos) async {
    if (!_modoAgregar) return;

    setState(() {
      _marcadorTemporal = Marker(
        markerId: const MarkerId('nuevo_punto'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    });

    final cliente = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => BuscarClientePage(posicion: pos),
        fullscreenDialog: true,
      ),
    );

    if (cliente == null) {
      setState(() {
        _modoAgregar = false;
        _marcadorTemporal = null;
      });
      return;
    }

    final direccion = await _pedirDireccion();
    if (direccion == null || direccion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe ingresar una dirección.')),
      );
      return;
    }

    setState(() {
      final nuevo = {
        "direccion": direccion,
        "lat": pos.latitude,
        "lng": pos.longitude,
        "id_cliente": cliente["id_cliente"], 
      };

      _puntos.add(nuevo);
      _marcadores.add(
        Marker(
          markerId: MarkerId("punto_${_puntos.length}"),
          position: pos,
          infoWindow: InfoWindow(title: "Punto ${_puntos.length}"),
          icon: _puntos.length == 1
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      _modoAgregar = false;
      _marcadorTemporal = null;
    });
  }

  Future<String?> _pedirDireccion() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Dirección del punto"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Ejemplo: Av. Los Olivos 123",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ============================
  // GUARDAR RUTA
  // ============================
  Future<void> _guardarRuta() async {
    if (_camionSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Seleccione un camión.")));
      return;
    }

    if (_puntos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agregue al menos un punto a la ruta.")),
      );
      return;
    }

    try {
      final resp = await _api.crearRuta(
        idCamion: _camionSeleccionado!.idCamion,
        fecha: _fechaSeleccionada?.toIso8601String().split('T').first,
        puntos: _puntos,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp["message"] ?? "Ruta guardada correctamente"),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    }
  }

  // ============================
  // UI
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Ruta")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleModoAgregar,
        icon: Icon(_modoAgregar ? Icons.cancel : Icons.add_location_alt),
        label: Text(_modoAgregar ? "Cancelar" : "Agregar punto"),
        backgroundColor: _modoAgregar ? Colors.red : null,
      ),
      body: Column(
        children: [
          // 👇 Bloque superior con ComboBox y Fecha
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<Camion>(
                  value: _camionSeleccionado,
                  items: _camiones.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text("${c.placa} • ${c.marca} ${c.modelo}"),
                    );
                  }).toList(),
                  onChanged: (c) => setState(() => _camionSeleccionado = c),
                  decoration: const InputDecoration(
                    labelText: "Seleccionar camión",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _mostrarSelectorFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Fecha de la ruta",
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

          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-6.7714, -79.8409),
                zoom: 13,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTap,
              markers: {
                ..._marcadores,
                if (_marcadorTemporal != null) _marcadorTemporal!,
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Guardar Ruta"),
                onPressed: _guardarRuta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
