import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
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

      setState(() {
        _fechaSeleccionada =_fechaSeleccionada = _parseFecha(detalle.fecha);
      });

      final List<LatLng> coordenadas = [];

      for (int i = 0; i < puntos.length; i++) {
        final punto = puntos[i];
        final latLng = LatLng(punto.lat, punto.lng);
        coordenadas.add(latLng);

        _marcadores.add(Marker(
          markerId: MarkerId('punto_${punto.idPunto}'),
          position: latLng,
          infoWindow: InfoWindow(title: punto.direccion),
          icon: i == 0
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen) // primero
              : (i == puntos.length - 1
                  ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed) // último
                  : BitmapDescriptor.defaultMarker),
        ));
      }

      _polilineas.add(Polyline(
        polylineId: const PolylineId('ruta'),
        color: Colors.blue,
        width: 4,
        points: coordenadas,
      ));

      if (coordenadas.isNotEmpty) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(coordenadas.first, 13),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando puntos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fecha',
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta actualizada con éxito')),
        );
        Navigator.pop(context); // volver a gestionar_ruta
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando ruta: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Ruta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(0, 0),
                      zoom: 12,
                    ),
                    markers: _marcadores,
                    polylines: _polilineas,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),
                ),
                _buildSelectorFecha(),
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
