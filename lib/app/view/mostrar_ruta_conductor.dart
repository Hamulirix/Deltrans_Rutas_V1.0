// mostrar_ruta_conductor.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_application_1/app/services/api_service.dart';

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
  bool _primerInicio = true;

  int? _idRuta;
  List<PuntoRutaDet> _puntos = [];
  int _indexActual = 0;
  PuntoRutaDet? get _puntoActual =>
      (_indexActual >= 0 && _indexActual < _puntos.length)
      ? _puntos[_indexActual]
      : null;

  // Ubicación
  LatLng? _posicionActual;

  // Polyline actual
  List<LatLng> _polylinePoints = [];

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

 @override
void dispose() {
  _posSub?.cancel();

  if (!_mapController.isCompleted) {
    _mapController.completeError(Exception('disposed'));
  }

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

      final desvios = await _api.listarDesviosActivos();

      setState(() {
        _idRuta = r.idRuta;
        _puntos = [...r.puntos]..sort((a, b) => a.orden.compareTo(b.orden));
        _indexActual = 0;
        _cargando = false;

        // 👇 Dibujar desvíos (incidentes activos)
        for (final d in desvios) {
          _markers.add(
            Marker(
              markerId: MarkerId('desvio_${d.lat}_${d.lng}'),
              position: LatLng(d.lat, d.lng),

              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: const InfoWindow(title: 'Zona con incidente'),
            ),
          );
        }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    _markers.add(
      Marker(
        markerId: const MarkerId('yo'),
        position: _posicionActual!,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
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
      _markers.add(
        Marker(
          markerId: MarkerId('p_${p.idPunto}'),
          position: LatLng(p.latitud, p.longitud),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '#${p.orden} • ${p.cliente.nombres}',
            snippet: '${p.direccion} • ${p.cliente.giro}',
          ),
        ),
      );
    }
    setState(() {});
  }

  // ============================
  // Seguimiento en tiempo real
  // ============================
  Future<void> _iniciarSeguimientoTiempoReal() async {
    if (_puntos.isEmpty) return;

    _posSub?.cancel();

    bool procesandoLlegada = false;
    final Set<int> puntosVisitados = {};

    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((pos) async {
          _posicionActual = LatLng(pos.latitude, pos.longitude);
          _actualizarMarcadorYo();

          if (_puntoActual == null || procesandoLlegada) return;

          // 🚨 Detectar desvío del Polyline
          if (_polylinePoints.isNotEmpty) {
            final distMin = _distanciaMinimaAPolyline(
              _posicionActual!,
              _polylinePoints,
            );

            // Ignorar el primer cálculo para evitar falso positivo
            if (!_primerInicio && distMin > 60) {
              _posSub?.pause();
              await _mostrarModalDesvio();
              _posSub?.resume();
            }
            _primerInicio = false;
          }

          final destino = LatLng(_puntoActual!.latitud, _puntoActual!.longitud);

          // Actualiza el trazado
          await _trazarRuta(_posicionActual!, destino);
          await _ajustarCamara(_posicionActual!, _puntoActual!);

          final dist = Geolocator.distanceBetween(
            _posicionActual!.latitude,
            _posicionActual!.longitude,
            destino.latitude,
            destino.longitude,
          );

          if (dist < 40 && !puntosVisitados.contains(_puntoActual!.idPunto)) {
            procesandoLlegada = true;
            puntosVisitados.add(_puntoActual!.idPunto);
            await _onLlegadaAPunto(_puntoActual!);
            procesandoLlegada = false;
          }
        });
  }

  double _distanciaMinimaAPolyline(LatLng p, List<LatLng> polyline) {
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      double d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        polyline[i].latitude,
        polyline[i].longitude,
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  // ============================
  // Modal de desvío
  // ============================
  Future<void> _mostrarModalDesvio() async {
    if (!mounted) return;

    String? motivo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desvío detectado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Parece que te desviaste de la ruta. ¿Cuál fue el motivo?',
            ),
            const SizedBox(height: 10),
            for (final m in [
              'Calle cerrada',
              'Mucho tráfico',
              'Desvío por obras',
              'Otro',
            ])
              ListTile(title: Text(m), onTap: () => Navigator.pop(context, m)),
          ],
        ),
      ),
    );

    if (motivo != null && _idRuta != null && _posicionActual != null) {
      await _api.registrarDesvio(
        idRuta: _idRuta!,
        motivo: motivo,
        lat: _posicionActual!.latitude,
        lng: _posicionActual!.longitude,
      );

      _toast('Desvío registrado: $motivo');

      // Agregar marcador visual del desvío
      _markers.add(
        Marker(
          markerId: MarkerId('desvio_${DateTime.now().millisecondsSinceEpoch}'),
          position: _posicionActual!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: 'Desvío: $motivo'),
        ),
      );

      // Recalcular la ruta desde donde está hacia el siguiente punto
      if (_puntoActual != null) {
        await _trazarRuta(
          _posicionActual!,
          LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
        );
      }
    }
  }

  // ============================
  // Llegada a un punto
  // ============================
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
      await _trazarRuta(_posicionActual!, LatLng(sig.latitud, sig.longitud));
      await _ajustarCamara(_posicionActual!, sig);
    } else {
      try {
        if (_idRuta != null) {
          await _api.actualizarEstadoRuta(idRuta: _idRuta!, estado: false);
        }
      } catch (e) {
        _toast('No pude marcar la ruta como finalizada: $e');
      }
      _toast('Ruta completada');
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ============================
  // Directions API + cámara
  // ============================
  Future<void> _trazarRuta(LatLng origen, LatLng destino) async {
    try {
      final pts = await _api.trazarRutaEvitarDesvios(
        origen: origen,
        destino: destino,
      );
      _polylinePoints = pts;

      _polylines
        ..removeWhere((p) => p.polylineId == const PolylineId('nav'))
        ..add(
          Polyline(
            polylineId: const PolylineId('nav'),
            points: pts,
            width: 6,
            color: Colors.blue,
          ),
        );
      setState(() {});
    } catch (e) {
      _toast('Error al trazar ruta: $e');
    }
  }

  Future<void> _ajustarCamara(LatLng origen, PuntoRutaDet destino) async {
    if (!mounted) return; // evita acceso tras salir
    if (!_mapController.isCompleted) return;

    final ctrl = await _mapController.future;
    if (ctrl == null) return;

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

    try {
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 96));
    } catch (_) {
      // Si el mapa fue destruido, ignorar sin lanzar excepción
    }
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
                          Text(
                            'Orden: ${_puntoActual!.orden}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
