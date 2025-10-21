// mostrar_ruta_conductor.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/app/services/api_service.dart';
import 'package:flutter_application_1/core/constants.dart';

class MostrarRutaConductorPage extends StatefulWidget {
  final String placa;
  final DateTime fecha;

  const MostrarRutaConductorPage({
    Key? key,
    required this.placa,
    required this.fecha,
  }) : super(key: key);

  @override
  State<MostrarRutaConductorPage> createState() =>
      _MostrarRutaConductorPageState();
}

class _MostrarRutaConductorPageState extends State<MostrarRutaConductorPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final ApiService _api = ApiService();

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _posSub;

  // Datos de la ruta
  int? _idRuta;
  List<PuntoRutaDet> _puntos = [];
  int _indexActual = 0;
  PuntoRutaDet? get _puntoActual =>
      (_indexActual >= 0 && _indexActual < _puntos.length)
          ? _puntos[_indexActual]
          : null;

  // Ubicación
  LatLng? _posicionActual;

  bool _cargando = true;
  static const _GOOGLE_API_KEY = AppConfig.googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  // ============================
  // Carga inicial (ruta + puntos)
  // ============================
  Future<void> _cargarRuta() async {
    try {
      final r = await _api.obtenerPuntosRuta(
        placa: widget.placa,
        fecha: widget.fecha,
      );

      setState(() {
        _idRuta = r.idRuta;
        _puntos = [...r.puntos]..sort((a, b) => a.orden.compareTo(b.orden));
        _indexActual = 0;
        _cargando = false;
      });

      await _obtenerUbicacionActual();
      _dibujarMarcadoresPuntos();
      if (_posicionActual != null && _puntoActual != null) {
        await _trazarRuta(
          _posicionActual!,
          LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
        );
        await _ajustarCamara(_posicionActual!, _puntoActual!);
      }
      await _iniciarSeguimientoTiempoReal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _cargando = false);
    }
  }

  // ============================
  // Geolocalización
  // ============================
  Future<void> _obtenerUbicacionActual() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _toast('Activa el GPS.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Permiso de ubicación denegado.');
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    _posicionActual = LatLng(pos.latitude, pos.longitude);
    _actualizarMarcadorYo();
  }

  void _actualizarMarcadorYo() {
    if (_posicionActual == null) return;
    _markers.removeWhere((m) => m.markerId == const MarkerId('yo'));
    _markers.add(Marker(
      markerId: const MarkerId('yo'),
      position: _posicionActual!,
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));
    setState(() {});
  }

  // ============================
  // Marcadores de puntos
  // ============================
  void _dibujarMarcadoresPuntos() {
    _markers.removeWhere((m) => m.markerId.value.startsWith('p_'));
    for (int i = 0; i < _puntos.length; i++) {
      final p = _puntos[i];
      final hue = i == 0
          ? BitmapDescriptor.hueGreen
          : (i == _puntos.length - 1
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueRose);
      _markers.add(Marker(
        markerId: MarkerId('p_${p.idPunto}'),
        position: LatLng(p.latitud, p.longitud),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: '#${p.orden} • ${p.cliente.nombres}',
          snippet: '${p.direccion} • ${p.cliente.giro}',
        ),
      ));
    }
    setState(() {});
  }

  // ============================
  // Tracking en tiempo real
  // ============================
  Future<void> _iniciarSeguimientoTiempoReal() async {
    if (_puntos.isEmpty) return;

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      _posicionActual = LatLng(pos.latitude, pos.longitude);
      _actualizarMarcadorYo();

      if (_puntoActual != null) {
        final destino =
            LatLng(_puntoActual!.latitud, _puntoActual!.longitud);

        // Redibuja navegación (polyline) y ajusta cámara
        await _trazarRuta(_posicionActual!, destino);
        await _ajustarCamara(_posicionActual!, _puntoActual!);

        // ¿Llegó?
        final dist = Geolocator.distanceBetween(
          _posicionActual!.latitude,
          _posicionActual!.longitude,
          destino.latitude,
          destino.longitude,
        );

        if (dist < 40) {
          await _onLlegadaAPunto(_puntoActual!);
        }
      }
    });
  }

  // Al llegar a un punto
  Future<void> _onLlegadaAPunto(PuntoRutaDet punto) async {
    _toast('Llegaste a ${punto.cliente.nombres}');
    try {
      if (_idRuta != null) {
        await _api.marcarPuntoVisitado(
          idRuta: _idRuta!,
          idPunto: punto.idPunto,
        );
      }
    } catch (e) {
      _toast('No pude marcar el punto como visitado: $e');
    }

    // Avanzar al siguiente
    if (_indexActual < _puntos.length - 1) {
      setState(() => _indexActual++);
      final sig = _puntoActual!;
      await _trazarRuta(
        _posicionActual!,
        LatLng(sig.latitud, sig.longitud),
      );
      await _ajustarCamara(_posicionActual!, sig);
    } else {
      // Terminado: inactivar ruta y volver
      try {
        if (_idRuta != null) {
          await _api.actualizarEstadoRuta(idRuta: _idRuta!, estado: false);
        }
      } catch (e) {
        _toast('No pude marcar la ruta como finalizada: $e');
      }
      _toast('Ruta completada');
      if (mounted) Navigator.of(context).pop(); // volver a la pantalla anterior
    }
  }

  // ============================
  // Directions API + cámara
  // ============================
  Future<void> _trazarRuta(LatLng origen, LatLng destino) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origen.latitude},${origen.longitude}'
        '&destination=${destino.latitude},${destino.longitude}'
        '&mode=driving&language=es&key=$_GOOGLE_API_KEY',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body);
      if (data['status'] != 'OK') return;

      final encoded = data['routes'][0]['overview_polyline']['points'] as String;
      final pts = _decodePolyline(encoded);

      _polylines
        ..removeWhere((p) => p.polylineId == const PolylineId('nav'))
        ..add(Polyline(
          polylineId: const PolylineId('nav'),
          points: pts,
          width: 6,
          color: Colors.blue,
        ));
      setState(() {});
    } catch (_) {}
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift; shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift; shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  Future<void> _ajustarCamara(LatLng origen, PuntoRutaDet destino) async {
    final ctrl = await (_mapController.isCompleted
        ? _mapController.future
        : Future<GoogleMapController?>.value(null));
    if (ctrl == null) return;

    // Bounds entre tu ubicación y el destino actual
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(origen.latitude, destino.latitud),
        math.min(origen.longitude, destino.longitud),
      ),
      northeast: LatLng(
        math.max(origen.latitude, destino.latitud),
        math.max(origen.longitude, destino.longitud),
      ),
    );
    await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 96));
  }

  // ============================
  // UI
  // ============================
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-6.77, -79.84),
                    zoom: 12,
                  ),
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (c) {
                    if (!_mapController.isCompleted) _mapController.complete(c);
                  },
                ),

                // Ventana de info del cliente actual
                if (_puntoActual != null)
                  Positioned(
                    top: 28,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Orden: ${_puntoActual!.orden}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text('Código: ${_puntoActual!.cliente.codigo}'),
                          Text('Cliente: ${_puntoActual!.cliente.nombres}'),
                          Text('Giro: ${_puntoActual!.cliente.giro}'),
                          Text('Dirección: ${_puntoActual!.direccion}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
