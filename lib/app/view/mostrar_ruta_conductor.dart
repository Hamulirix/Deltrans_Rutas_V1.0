// mostrar_ruta_conductor.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/app/services/api_service.dart';

class RoutePreviewScreen extends StatefulWidget {
  final String placa;
  final DateTime fecha;

  const RoutePreviewScreen({
    Key? key,
    required this.placa,
    required this.fecha,
  }) : super(key: key);

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final _api = ApiService();
  final Completer<GoogleMapController> _mapCtrl = Completer();
  late Future<RutaConPuntos> _future;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLngBounds? _bounds;
  StreamSubscription<Position>? _posSub;

  final _meMarkerId = const MarkerId('yo');
  final _trailId = const PolylineId('trail');
  final _navId = const PolylineId('navegacion');
  final List<LatLng> _trail = [];
  bool _tracking = false;
  int _indexActual = 0;

  // Tu API Key de Google Directions
  static const _GOOGLE_API_KEY = AppConfig.googleMapsApiKey;

  DateTime _lastDraw = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastOrigin;

  @override
  void initState() {
    super.initState();
    _future = _api.obtenerPuntosRuta(placa: widget.placa, fecha: widget.fecha);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  // ========== DIBUJAR MAPA BASE ==========
  void _construirMapa(RutaConPuntos r) {
    _markers.clear();
    _polylines.clear();

    final pts = [...r.puntos]..sort((a, b) => a.orden.compareTo(b.orden));
    final coords = <LatLng>[for (final p in pts) LatLng(p.latitud, p.longitud)];

    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final hue = i == 0
          ? BitmapDescriptor.hueGreen
          : (i == pts.length - 1
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueAzure);

      _markers.add(Marker(
        markerId: MarkerId('p_${p.idPunto}'),
        position: LatLng(p.latitud, p.longitud),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow:
            InfoWindow(title: '#${p.orden} • ${p.cliente.nombres}', snippet: p.direccion),
      ));
    }

    _polylines.add(Polyline(
      polylineId: const PolylineId('ruta'),
      width: 3,
      points: coords,
      color: Colors.grey.shade400,
    ));

    _bounds = _calcularBounds(coords);
  }

  LatLngBounds _calcularBounds(List<LatLng> coords) {
    double minLat = coords.first.latitude, maxLat = coords.first.latitude;
    double minLng = coords.first.longitude, maxLng = coords.first.longitude;
    for (final c in coords.skip(1)) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fitToBounds() async {
    if (_bounds == null) return;
    final ctrl = await _mapCtrl.future;
    await ctrl.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 60));
  }

  // ========== DIRECTIONS API ==========
  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    final now = DateTime.now();
    if (_lastOrigin != null) {
      final dist = Geolocator.distanceBetween(
          _lastOrigin!.latitude, _lastOrigin!.longitude, origin.latitude, origin.longitude);
      if (dist < 10 && now.difference(_lastDraw).inSeconds < 10) return;
    }

    _lastOrigin = origin;
    _lastDraw = now;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving&key=$_GOOGLE_API_KEY');

    final resp = await http.get(url);
    if (resp.statusCode != 200) return;

    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK') return;

    final route = data['routes'][0];
    final points = _decodePolyline(route['overview_polyline']['points']);
    _polylines.removeWhere((p) => p.polylineId == _navId);
    _polylines.add(Polyline(
      polylineId: _navId,
      points: points,
      color: Colors.blue,
      width: 6,
    ));
    setState(() {});
  }

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
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  // ========== PERMISOS + TRACKING ==========
  Future<bool> _asegurarPermisos() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> _iniciarRuta(RutaConPuntos ruta) async {
    if (!await _asegurarPermisos()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Activa permisos/GPS para iniciar la ruta')));
      return;
    }

    setState(() => _tracking = true);
    _trail.clear();

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) async {
      final latLng = LatLng(pos.latitude, pos.longitude);

      // marcador del conductor
      _markers.removeWhere((m) => m.markerId == _meMarkerId);
      _markers.add(Marker(
        markerId: _meMarkerId,
        position: latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ));

      // dibujar rastro
      _trail.add(latLng);
      _polylines.removeWhere((p) => p.polylineId == _trailId);
      _polylines.add(Polyline(polylineId: _trailId, points: List.of(_trail), color: Colors.indigo));

      // centrado
      final ctrl = await _mapCtrl.future;
      ctrl.animateCamera(CameraUpdate.newLatLng(latLng));

      // actualizar ruta Directions API
      final pts = [...ruta.puntos]..sort((a, b) => a.orden.compareTo(b.orden));
      if (_indexActual < pts.length) {
        final destino = LatLng(pts[_indexActual].latitud, pts[_indexActual].longitud);
        _drawRoute(latLng, destino);

        // Llegada al punto
        final distM = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, destino.latitude, destino.longitude);
        if (distM < 40) {
          _mostrarModalPunto(pts[_indexActual], onSeleccion: (entregado) async {
            await _api.marcarVisita(idPunto: pts[_indexActual].idPunto, entregado: entregado);
            Navigator.of(context).pop();
            setState(() => _indexActual = math.min(_indexActual + 1, pts.length - 1));
          });
        }
      }

      setState(() {});
    });
  }

  // ========== MODAL ==========
  void _mostrarModalPunto(PuntoRutaDet punto, {required void Function(bool) onSeleccion}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('N° pedido:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('${punto.orden}'),
          ]),
          _info('Dirección', punto.direccion),
          _info('Giro', punto.cliente.giro),
          _info('Cliente', punto.cliente.nombres),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(punto.latitud, punto.longitud),
                zoom: 16,
              ),
              markers: {
                Marker(
                    markerId: const MarkerId('dest'),
                    position: LatLng(punto.latitud, punto.longitud),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed))
              },
              liteModeEnabled: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => onSeleccion(false), child: const Text('No entregado'))),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
                    onPressed: () => onSeleccion(true), child: const Text('Entregado'))),
          ]),
        ]),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(v)),
        ]),
      );

  // ========== UI ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta asignada')),
      body: FutureBuilder<RutaConPuntos>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final ruta = snap.data!;
          _construirMapa(ruta);

          final target = _bounds == null
              ? const LatLng(-12.0464, -77.0428)
              : LatLng((_bounds!.northeast.latitude + _bounds!.southwest.latitude) / 2,
                  (_bounds!.northeast.longitude + _bounds!.southwest.longitude) / 2);

          return Column(children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: target, zoom: 12),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: _tracking,
                compassEnabled: true,
                zoomControlsEnabled: false,
                onMapCreated: (c) async {
                  _mapCtrl.complete(c);
                  await Future.delayed(const Duration(milliseconds: 300));
                  _fitToBounds();
                },
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _tracking ? null : () => _iniciarRuta(ruta),
                    child: Text(_tracking ? 'Ruta en curso…' : 'Iniciar ruta'),
                  ),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
