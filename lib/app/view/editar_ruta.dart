import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';
import 'package:flutter_application_1/app/view/buscar_cliente.dart';

class EditarRutaMapaPage extends StatefulWidget {
  final int idRuta;

  const EditarRutaMapaPage({super.key, required this.idRuta});

  @override
  State<EditarRutaMapaPage> createState() => _EditarRutaMapaPageState();
}

class _EditarRutaMapaPageState extends State<EditarRutaMapaPage> {
  final _api = ApiService();
  final Set<Marker> _marcadores = {};
  final Set<Polyline> _polilineas = {};
  GoogleMapController? _mapController;
  DateTime? _fechaSeleccionada;
  bool _loading = true;
  bool _modoAgregar = false;
  Marker? _marcadorTemporal;
  List<Map<String, dynamic>> _listaPuntos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  DateTime? _parseFecha(String? fecha) {
    if (fecha == null) return null;
    final partes = fecha.split('/');
    if (partes.length != 3) return null;
    final day = int.tryParse(partes[0]) ?? 1;
    final month = int.tryParse(partes[1]) ?? 1;
    final year = int.tryParse(partes[2]) ?? 2000;
    return DateTime(year, month, day);
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final puntos = await _api.listarPuntosDeRuta(widget.idRuta);
      final detalle = await _api.obtenerDetalleRuta(widget.idRuta);

      final List<LatLng> coordenadas = [];
      final marcadoresTemp = <Marker>{};
      final polilineasTemp = <Polyline>{};
      final listaTemp = <Map<String, dynamic>>[];

      for (int i = 0; i < puntos.length; i++) {
        final punto = puntos[i];
        final latLng = LatLng(punto.lat, punto.lng);
        coordenadas.add(latLng);

        listaTemp.add({
          "id_ruta_punto": punto.idPunto,
          "direccion": punto.direccion,
          "lat": punto.lat,
          "lng": punto.lng,
          "numero": punto.numero,
        });

        marcadoresTemp.add(
          Marker(
            markerId: MarkerId('punto_${punto.idPunto}'),
            position: latLng,
            infoWindow: InfoWindow(title: "Punto ${punto.numero}"),
            icon: i == 0
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  )
                : (i == puntos.length - 1
                      ? BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        )
                      : BitmapDescriptor.defaultMarker),
            onTap: () => _mostrarAccionesPunto(punto.idPunto, punto.numero),
          ),
        );
      }

      if (coordenadas.isNotEmpty) {
        polilineasTemp.add(
          Polyline(
            polylineId: const PolylineId('ruta'),
            color: Colors.blue,
            width: 4,
            points: coordenadas,
          ),
        );
      }

      setState(() {
        _fechaSeleccionada = _parseFecha(detalle.fecha);
        _marcadores
          ..clear()
          ..addAll(marcadoresTemp);
        _polilineas
          ..clear()
          ..addAll(polilineasTemp);
        _listaPuntos = listaTemp;
        _loading = false;
      });

      if (coordenadas.isNotEmpty && _mapController != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(_boundsFromLatLngList(coordenadas), 60),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
      }
      setState(() => _loading = false);
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    final southwestLat = list
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final southwestLng = list
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final northeastLat = list
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final northeastLng = list
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);
    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );
  }

  void _mostrarSelectorFechaSimple() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar fecha'),
        content: SizedBox(
          width: double.maxFinite,
          child: CalendarDatePicker(
            initialDate: _fechaSeleccionada ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (DateTime value) {
              setState(() => _fechaSeleccionada = value);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorFecha() {
    final text = _fechaSeleccionada == null
        ? ''
        : '${_fechaSeleccionada!.day.toString().padLeft(2, '0')}-'
              '${_fechaSeleccionada!.month.toString().padLeft(2, '0')}-'
              '${_fechaSeleccionada!.year}';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fecha de la ruta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(text: text),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintText: 'DD-MM-AAAA',
                    ),
                    readOnly: true,
                    onTap: _mostrarSelectorFechaSimple,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _mostrarSelectorFechaSimple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

void _guardarYVolver() async {
  try {
    await _api.actualizarFechaRuta(
      idRuta: widget.idRuta,
      fecha: _fechaSeleccionada,
    );

    if (!mounted) return;

    // ✅ Solo muestra un feedback visual simple (sin Navigator.pop)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ruta actualizada con éxito')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error guardando ruta: $e')),
    );
  }
}


  // =====================================================
  // NUEVO: Modal con opciones (Reordenar / Eliminar)
  // =====================================================
  void _mostrarAccionesPunto(int idRutaPunto, int numero) {
    final controller = TextEditingController(text: numero.toString());
    final totalPuntos = _listaPuntos.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Punto actual: $numero",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Nuevo orden (1..$totalPuntos)",
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.swap_vert),
                      label: const Text("Cambiar orden"),
                      onPressed: () async {
                        final val = int.tryParse(controller.text.trim());
                        if (val == null || val < 1 || val > totalPuntos) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "El número debe estar entre 1 y $totalPuntos.",
                              ),
                            ),
                          );
                          return;
                        }

                        if (val == numero) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "El punto ya tiene ese mismo orden.",
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);

                        try {
                          await _api.reordenarPuntoDeRuta(
                            idRuta: widget.idRuta,
                            idRutaPunto: idRutaPunto,
                            nuevoOrden: val,
                          );

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Orden actualizado correctamente."),
                            ),
                          );
                          await _cargarDatosIniciales();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error al reordenar: $e")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Eliminar punto"),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await _api.eliminarPuntoDeRuta(
                            idRuta: widget.idRuta,
                            idRutaPunto: idRutaPunto,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Punto eliminado correctamente."),
                            ),
                          );
                          await _cargarDatosIniciales();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error al eliminar: $e")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // NUEVO: Modo agregar punto tocando el mapa
  // =====================================================
  void _toggleModoAgregar() {
    setState(() {
      _modoAgregar = !_modoAgregar;
      _marcadorTemporal = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _modoAgregar
              ? 'Toca el mapa para elegir la ubicación del nuevo punto.'
              : 'Modo agregar cancelado.',
        ),
      ),
    );
  }

  Future<void> _onMapTap(LatLng position) async {
    if (!_modoAgregar) return;

    setState(() {
      _marcadorTemporal = Marker(
        markerId: const MarkerId('nuevo_punto'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    });

    final clienteSeleccionado = await Navigator.of(context)
        .push<Map<String, dynamic>?>(
          MaterialPageRoute(
            builder: (_) => BuscarClientePage(posicion: position),
            fullscreenDialog: true,
          ),
        );

    if (clienteSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Operación cancelada.')));
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
      setState(() {
        _modoAgregar = false;
        _marcadorTemporal = null;
      });
      return;
    }

    final idCliente = clienteSeleccionado['id_cliente'];
    if (idCliente == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente inválido.')));
      setState(() {
        _modoAgregar = false;
        _marcadorTemporal = null;
      });
      return;
    }

    await _api.agregarPuntoARuta(
      idRuta: widget.idRuta,
      direccion: direccion,
      latitud: position.latitude,
      longitud: position.longitude,
      idCliente: idCliente,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Punto agregado correctamente.')),
    );

    setState(() {
      _modoAgregar = false;
      _marcadorTemporal = null;
    });

    await _cargarDatosIniciales();
  }

  Future<String?> _pedirDireccion() async {
    final controller = TextEditingController();
    return await showDialog<String>(
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

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Ruta')),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(_modoAgregar ? Icons.cancel : Icons.add_location_alt),
        label: Text(_modoAgregar ? "Cancelar" : "Agregar punto"),
        backgroundColor: _modoAgregar ? Colors.red : null,
        onPressed: _toggleModoAgregar,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSelectorFecha(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(-12.0464, -77.0428),
                        zoom: 12,
                      ),
                      markers: {
                        ..._marcadores,
                        if (_marcadorTemporal != null) _marcadorTemporal!,
                      },
                      polylines: _polilineas,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_polilineas.isNotEmpty) {
                          final puntos = _polilineas.first.points;
                          if (puntos.isNotEmpty) {
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (!mounted) return;
                                try {
                                  controller.animateCamera(
                                    CameraUpdate.newLatLngBounds(
                                      _boundsFromLatLngList(puntos),
                                      60,
                                    ),
                                  );
                                } catch (_) {}
                              },
                            );
                          }
                        }
                      },

                      onTap: _onMapTap,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar ruta'),
                      onPressed: _guardarYVolver,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
