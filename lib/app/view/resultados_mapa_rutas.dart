import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ResultadoRutasMapaPage extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const ResultadoRutasMapaPage({super.key, required this.apiData});

  @override
  State<ResultadoRutasMapaPage> createState() => _ResultadoRutasMapaPageState();
}

class _ResultadoRutasMapaPageState extends State<ResultadoRutasMapaPage> {
  GoogleMapController? _mapController;
  Set<Marker> _marcadores = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _puntosRuta = [];
  String? _nombreRuta;
  int _totalPuntos = 0;

  @override
  void initState() {
    super.initState();
    _procesarDatos();
  }

  void _procesarDatos() {
    try {
      final resultados = widget.apiData["resultados"][0];
      final ruta = resultados["rutas"][0];

      _nombreRuta = ruta["nombre"];
      _totalPuntos = ruta["total_puntos"];

      final puntos = ruta["puntos"] as List;

      for (int i = 0; i < puntos.length; i++) {
        final punto = puntos[i];
        LatLng pos = LatLng(punto["latitude"], punto["longitude"]);
        _puntosRuta.add(pos);

        // Diferenciar origen y destino
        BitmapDescriptor icono;
        if (i == 0) {
          icono = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen); // Origen
        } else if (i == puntos.length - 1) {
          icono = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed); // Destino
        } else {
          icono = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure); // Intermedios
        }

        _marcadores.add(
          Marker(
            markerId: MarkerId("punto_$i"),
            position: pos,
            infoWindow: InfoWindow(
              title: "Punto ${i + 1}",
              snippet: punto["cliente"],
            ),
            icon: icono,
          ),
        );
      }

      // Trazo de la ruta
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("ruta_optima"),
          points: _puntosRuta,
          color: Colors.blue,
          width: 4,
        ),
      );
    } catch (e) {
      debugPrint("Error procesando datos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = widget.apiData["resultados"][0]["resumen"];

    return Scaffold(
      appBar: AppBar(title: const Text("Resultado de las rutas")),
      body: Column(
        children: [
          // 🔹 Resumen en 2 columnas
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Distancia optimizada:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${resumen["distancia_opt_km"]} km"),
                            SizedBox(height: 6),
                            Text("Tiempo optimizado:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${resumen["tiempo_opt_hor"]} horas"),
                            SizedBox(height: 6),
                            Text("Mejora distancia:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${resumen["mejora_distancia_pct"]}%"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Distancia original:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${resumen["distancia_original_km"]} km"),
                            SizedBox(height: 6),
                            Text("Tiempo original:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${resumen["tiempo_original_hor"]} horas"),
                            SizedBox(height: 6),
                            Text("Mejora tiempo:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${resumen["mejora_tiempo_pct"]}%"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 🔹 Selector de ruta
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: _nombreRuta,
              items: [
                DropdownMenuItem(
                  value: _nombreRuta,
                  child: Text("$_nombreRuta - $_totalPuntos puntos"),
                )
              ],
              onChanged: (value) {},
              decoration: const InputDecoration(
                labelText: "Ruta",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // 🔹 Mapa
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                if (_puntosRuta.isNotEmpty) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      _boundsFromLatLngList(_puntosRuta),
                      50,
                    ),
                  );
                }
              },
              initialCameraPosition: CameraPosition(
                target: _puntosRuta.isNotEmpty ? _puntosRuta[0] : const LatLng(0, 0),
                zoom: 14,
              ),
              markers: _marcadores,
              polylines: _polylines,
            ),
          ),

          // 🔹 Botones
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () {}, child: const Text("Editar ruta")),
                ElevatedButton(onPressed: () {}, child: const Text("Guardar ruta")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Calcula límites para ajustar cámara a todos los puntos
  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(x0, y0),
      northeast: LatLng(x1, y1),
    );
  }
}
