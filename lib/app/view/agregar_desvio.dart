/*import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CrearDesvioPage extends StatefulWidget {
  const CrearDesvioPage({super.key});

  @override
  State<CrearDesvioPage> createState() => _CrearDesvioPageState();
}

class _CrearDesvioPageState extends State<CrearDesvioPage> {
  bool _saving = false;
  final TextEditingController _motivoCtrl = TextEditingController();
  DateTime? _fecha;
  String _estado = 'Activo';
  LatLng? _posSeleccionada;
  GoogleMapController? _mapCtrl;

  final _api = ApiService();
  @override
  void dispose() {
    _motivoCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

    void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (f != null) setState(() => _fecha = f);
  }

  void _onMapaTap(LatLng pos) {
    setState(() => _posSeleccionada = pos);
  }



  Future<void> _guardar() async {
    if (_motivoCtrl.text.trim().isEmpty) {
      _toast('Ingrese motivo');
      return;
    }
    if (_posSeleccionada == null) {
      _toast('Seleccione la ubicación en el mapa');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _api.registrarDesvio2(
        motivo: _motivoCtrl.text.trim(),
        lat: _posSeleccionada!.latitude,
        lng: _posSeleccionada!.longitude,
      );
      _toast(res['message'] ?? 'Desvío registrado');
      Navigator.pop(context, true);
    } catch (e) {
      _toast('Error al registrar desvío: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaTexto = _fecha == null
        ? 'Seleccionar fecha'
        : '${_fecha!.day.toString().padLeft(2, '0')}/${_fecha!.month.toString().padLeft(2, '0')}/${_fecha!.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Añadir Desvío')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFecha,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(fechaTexto),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _estado,
                  items: const [
                    DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                    DropdownMenuItem(value: 'Inactivo', child: Text('Inactivo')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _estado = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-12.0464, -77.0428), 
                      zoom: 12,
                    ),
                    onMapCreated: (c) => _mapCtrl = c,
                    onTap: _onMapaTap,
                    markers: _posSeleccionada == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId('sel'),
                              position: _posSeleccionada!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                            ),
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _posSeleccionada = null);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Limpiar ubicación'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar desvío'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

      /*
            // ➕ FAB crear
            floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool?>(
            context,
            MaterialPageRoute(builder: (_) => const CrearDesvioPage()),
          );
          if (created == true) {
            await _cargarDesvios();
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),



        Future<Map<String, dynamic>> registrarDesvio2({
    required String motivo,
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('$baseUrl/rutas/desvio'); // baseUrl ya incluye /api
    final headers = await _jsonHeaders(withAuth: true);

    final body = jsonEncode({
      'motivo': motivo,
      'lat': lat,
      'lng': lng,
    });

    final resp = await http.post(uri, headers: headers, body: body);

    return _handleResponse<Map<String, dynamic>>(
      resp,
      (json) => json as Map<String, dynamic>,
    );
  }
      */
*/