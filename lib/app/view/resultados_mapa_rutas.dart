import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/asignar_rutas.dart';
import 'package:flutter_application_1/core/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

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

  // para encuadre al iniciar
  CameraUpdate? _pendingUpdate;

  String? _rutaSeleccionada;
  Map<String, dynamic>? _resumenSeleccionado;
  String? _placaSeleccionada;

  List<Map<String, dynamic>> _listaRutas = [];
  bool _modoEditar = false;
  bool _saving = false;


  static const String _googleApiKey = AppConfig.googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _cargarRutas();
    if (_listaRutas.isNotEmpty) {
      _cargarRuta(_listaRutas.first);
    }
  }

  void _cargarRutas() {
    try {
      for (var resultado in widget.apiData["resultados"]) {
        final placa = resultado["placa"];
        final resumen = resultado["resumen"];

        for (var ruta in resultado["rutas"]) {
          _listaRutas.add({
            "placa": placa,
            "resumen": resumen,
            "nombre": ruta["nombre"],
            "total_puntos": ruta["total_puntos"],
            "puntos": ruta["puntos"],
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando rutas: $e");
    }
  }

  void _cargarRuta(Map<String, dynamic> ruta) {
    final puntos = (ruta["puntos"] as List).cast<Map<String, dynamic>>();

    final nuevosPuntos = <LatLng>[];
    final nuevosMarkers = <Marker>{};

    for (int i = 0; i < puntos.length; i++) {
      final p = puntos[i];
      final pos = LatLng(
        (p["latitude"] as num).toDouble(),
        (p["longitude"] as num).toDouble(),
      );
      nuevosPuntos.add(pos);

      final icono = (i == 0)
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
          : (i == puntos.length - 1)
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

      nuevosMarkers.add(
        Marker(
          markerId: MarkerId("punto_$i"),
          position: pos,
          infoWindow: InfoWindow(
            title: "Punto ${i + 1}",
            snippet: (p["cliente"] ?? '').toString(),
          ),
          icon: icono,
          onTap: () {
            if (_modoEditar) _eliminarPunto(pos);
          },
        ),
      );
    }

    setState(() {
      _rutaSeleccionada = ruta["nombre"];
      _resumenSeleccionado = Map<String, dynamic>.from(ruta["resumen"]);
      _placaSeleccionada = ruta["placa"];
      _puntosRuta = nuevosPuntos;
      _marcadores = nuevosMarkers;
      _polylines = {};
    });

    // traza vial (o recta si falla)
    _drawRoadPolyline();
  }

  // =======================
  // Trazo "por calles"
  // =======================

  Future<void> _drawRoadPolyline() async {
    if (_puntosRuta.length < 2) {
      setState(() => _polylines.clear());
      return;
    }

    try {
      final roadPath = await _fetchRoadPath(_puntosRuta);

      if (!mounted) return;
      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId('ruta_vial_${_rutaSeleccionada ?? 'x'}'),
            points: roadPath,
            width: 5,
            color: Colors.lightBlue,
          ),
        };
      });

      // encuadre sobre el camino vial
      final b = _boundsFromLatLngList(roadPath);
      final update = CameraUpdate.newLatLngBounds(b, 50);
      _applyOrQueueCameraUpdate(update);
    } catch (e) {
      // fallback a líneas rectas
      if (!mounted) return;
      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId('ruta_recta_${_rutaSeleccionada ?? 'x'}'),
            points: _puntosRuta,
            width: 4,
            color: Colors.lightBlue,
          ),
        };
      });
      final b = _boundsFromLatLngList(_puntosRuta);
      _applyOrQueueCameraUpdate(CameraUpdate.newLatLngBounds(b, 50));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener ruta por calles: $e')),
      );
    }
  }

  // Divide en chunks (25 puntos máx. por request) y decodifica polyline
  Future<List<LatLng>> _fetchRoadPath(List<LatLng> puntos) async {
    const maxPerRequest = 25; // origin + destination + 23 waypoints
    final List<LatLng> resultPath = [];

    Future<void> fetchChunk(List<LatLng> chunk) async {
      if (chunk.length < 2) return;

      final origin =
          '${chunk.first.latitude},${chunk.first.longitude}';
      final destination =
          '${chunk.last.latitude},${chunk.last.longitude}';
      final waypoints = (chunk.length > 2)
          ? '&waypoints=${chunk.sublist(1, chunk.length - 1).map((p) => '${p.latitude},${p.longitude}').join('|')}'
          : '';

      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypoints&mode=driving&key=$_googleApiKey';

      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        throw Exception('Directions HTTP ${resp.statusCode}');
      }
      final data = json.decode(resp.body);
      if (data['status'] != 'OK' || (data['routes'] as List).isEmpty) {
        throw Exception('Directions error: ${data['status']}');
      }

      final overview = data['routes'][0]['overview_polyline']['points'] as String;
      final decoded = _decodePolyline(overview);

      // unir evitando duplicar el primer punto
      if (resultPath.isNotEmpty && decoded.isNotEmpty) {
        decoded.removeAt(0);
      }
      resultPath.addAll(decoded);
    }

    int start = 0;
    while (start < puntos.length - 1) {
      final endExclusive = (start + maxPerRequest).clamp(0, puntos.length);
      final chunk = puntos.sublist(start, endExclusive);
      await fetchChunk(chunk);
      start = endExclusive - 1; // solapar 1
    }

    return resultPath;
  }

  // Decodificador de polylines (Google)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  void _applyOrQueueCameraUpdate(CameraUpdate update) async {
    if (_mapController == null) {
      _pendingUpdate = update;
      return;
    }
    try {
      await _mapController!.animateCamera(update);
    } catch (_) {
      // si el mapa aún no tiene tamaño, reintenta en el próximo frame
      _pendingUpdate = update;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _mapController == null || _pendingUpdate == null) return;
        try {
          await _mapController!.animateCamera(_pendingUpdate!);
          _pendingUpdate = null;
        } catch (_) {}
      });
    }
  }

  // =======================
  // Recalcular & edición
  // =======================

  Future<void> _recalcularRuta() async {
    if (_puntosRuta.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Se necesitan al menos 2 puntos para recalcular la ruta.")),
      );
      return;
    }

    try {
      final puntos = _puntosRuta
          .map((p) => {"latitude": p.latitude, "longitude": p.longitude})
          .toList();

      final result = await ApiService().recalcularRuta(
        (puntos as List).cast<Map<String, double>>(),
      );

      if (result != null) {
        setState(() {
          _resumenSeleccionado!["distancia_opt_km"] = result["distancia_km"];
          _resumenSeleccionado!["tiempo_opt_hor"] = result["tiempo_horas"];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ruta recalculada: ${result["distancia_km"]} km, ${result["tiempo_horas"]} h")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo recalcular la ruta.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al recalcular: $e")),
      );
    }
  }

  void _eliminarPunto(LatLng pos) async {
    setState(() {
      _puntosRuta.remove(pos);
      _marcadores.removeWhere((m) => m.position == pos);
    });

    // Redibuja localmente (línea recta provisional)
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId("ruta_editada"),
          points: _puntosRuta,
          width: 4,
        ),
      };
    });

    await _recalcularRuta();
    // y vuelve a intentar trazo vial
    _drawRoadPolyline();
  }

  // =======================
  // Guardar en backend
  // =======================

  Map<String, dynamic> _payloadRutaSeleccionada() {
    if (_rutaSeleccionada == null || _placaSeleccionada == null) {
      throw Exception("No hay ruta o placa seleccionada");
    }

    final rutaOriginal =
        _listaRutas.firstWhere((r) => r["nombre"] == _rutaSeleccionada);
    final puntosOriginales =
        (rutaOriginal["puntos"] as List).cast<Map<String, dynamic>>();

    final Map<String, Map<String, dynamic>> porCoordenada = {};
    for (final p in puntosOriginales) {
      final key = "${p['latitude']},${p['longitude']}";
      porCoordenada[key] = p;
    }

    final puntosPayload = <Map<String, dynamic>>[];
    for (final pos in _puntosRuta) {
      final key = "${pos.latitude},${pos.longitude}";
      final base = porCoordenada[key];
      puntosPayload.add({
        "direccion": base?["direccion"] ?? "",
        "latitude": pos.latitude,
        "longitude": pos.longitude,
        "cliente": base?["cliente"] ?? "",
        "giro": base?["giro"] ?? "",
        "codigo": base?["codigo"] ?? "", // tu backend ya acepta 'codigo'
      });
    }

    return {
      "resultados": [
        {
          "placa": _placaSeleccionada,
          "rutas": [
            {"nombre": _rutaSeleccionada, "puntos": puntosPayload},
          ],
        },
      ],
    };
  }

  Future<void> _guardarRutas() async {
    if (_rutaSeleccionada == null ||
        _placaSeleccionada == null ||
        _puntosRuta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona una ruta válida antes de guardar.")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = _payloadRutaSeleccionada();
      final res = await ApiService().guardarRutas(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Rutas guardadas correctamente')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AsignarRutasPage()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final code = e.statusCode;
      final msg = (code == 401 || code == 403)
          ? 'Sesión expirada. Inicia sesión de nuevo.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =======================
  // UI
  // =======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resultado de las rutas")),
      body: Column(
        children: [
          if (_resumenSeleccionado != null)
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Camión: ${_placaSeleccionada ?? '-'}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Distancia optimizada:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${_resumenSeleccionado!["distancia_opt_km"]} km"),
                              const SizedBox(height: 4),
                              const Text("Distancia original:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${_resumenSeleccionado!["distancia_original_km"]} km"),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Tiempo optimizado:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${_resumenSeleccionado!["tiempo_opt_hor"]} horas"),
                              const SizedBox(height: 4),
                              const Text("Tiempo original:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${_resumenSeleccionado!["tiempo_original_hor"]} horas"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Mejora distancia: ${_resumenSeleccionado!["mejora_distancia_pct"]}%"),
                    Text("Mejora tiempo: ${_resumenSeleccionado!["mejora_tiempo_pct"]}%"),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: _rutaSeleccionada,
              items: _listaRutas.map((ruta) {
                return DropdownMenuItem<String>(
                  value: ruta["nombre"],
                  child: Text("${ruta["nombre"]} (${ruta["placa"]}) - ${ruta["total_puntos"]} pts"),
                );
              }).toList(),
              onChanged: (value) {
                final ruta = _listaRutas.firstWhere((r) => r["nombre"] == value);
                _cargarRuta(ruta);
              },
              decoration: const InputDecoration(
                labelText: "Selecciona una ruta",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_pendingUpdate != null) {
                  Future.microtask(() async {
                    try {
                      await _mapController!.animateCamera(_pendingUpdate!);
                    } catch (_) {}
                    _pendingUpdate = null;
                  });
                }
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(-7.241304, -79.471726),
                zoom: 12,
              ),
              markers: _marcadores,
              polylines: _polylines,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modoEditar ? Colors.orange : null,
                  ),
                  onPressed: () {
                    setState(() => _modoEditar = !_modoEditar);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _modoEditar
                              ? "Modo edición activado. Toca un punto para eliminarlo."
                              : "Modo edición desactivado.",
                        ),
                      ),
                    );
                  },
                  child: Text(_modoEditar ? "Salir de edición" : "Editar ruta"),
                ),
                ElevatedButton(
                  onPressed: _saving ? null : _guardarRutas,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Guardar ruta"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude, maxLat = list.first.latitude;
    double minLng = list.first.longitude, maxLng = list.first.longitude;
    for (final p in list) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
