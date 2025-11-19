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

  bool _primerInicio = true;

  int? _idRuta;
  List<PuntoRutaDet> _puntos = [];
  int _indexActual = 0;

  PuntoRutaDet? get _puntoActual =>
      (_indexActual >= 0 && _indexActual < _puntos.length)
          ? _puntos[_indexActual]
          : null;

  LatLng? _posicionActual;

  List<LatLng> _polylinePoints = [];

  bool _cargando = true;

  /// buffers para evitar falsos positivos de desvío
  final List<double> _historialDesvio = [];
  static const int _minLecturasConfirmar = 3;

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

  // ============================================
  // Cargar ruta inicial
  // ============================================
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

      final ok = await _asegurarUbicacionActiva();
      if (!ok) return; // evita crasheo
      _dibujarMarcadoresPuntos();

      if (_posicionActual != null && _puntoActual != null) {
        await _trazarRuta(
          _posicionActual!,
          LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
        );
        await _centrarEnRuta(_posicionActual!, _puntoActual!);
      }

      await _iniciarSeguimientoTiempoReal();
    } catch (e) {
      if (!mounted) return;
      _toast("Error: $e");
      setState(() => _cargando = false);
    }
  }

  // ============================================
  // Obtener ubicación del usuario
  // ============================================

Future<bool> _asegurarUbicacionActiva() async {
  try {
    // 1. Verificar si GPS está encendido
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 1));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _toast("Activa el GPS para continuar.");
        return false;
      }
    }

    // 2. Permisos actuales
    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      _toast("La app no tiene permisos de ubicación. Ve a Ajustes.");
      return false;
    }

    if (perm == LocationPermission.denied) {
      _toast("No otorgaste permisos de ubicación.");
      return false;
    }

    // 3. Intentar obtener ubicación (puede fallar)
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _posicionActual = LatLng(pos.latitude, pos.longitude);
      _actualizarMarcadorYo();
      return true; // OK
    } catch (e) {
      // Error común cuando el GPS recién está activándose
      await Future.delayed(const Duration(seconds: 2));
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _posicionActual = LatLng(pos.latitude, pos.longitude);
        _actualizarMarcadorYo();
        return true;
      } catch (_) {
        _toast("No pude obtener tu ubicación. Intenta de nuevo.");
        return false;
      }
    }
  } catch (e) {
    _toast("Error de ubicación: $e");
    return false;
  }
}



  void _actualizarMarcadorYo() {
    if (_posicionActual == null) return;
    _markers.removeWhere((m) => m.markerId == const MarkerId('yo'));
    _markers.add(
      Marker(
        markerId: const MarkerId('yo'),
        position: _posicionActual!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: "Tu ubicación"),
      ),
    );
    setState(() {});
  }

  // ============================================
  // Marcadores de puntos
  // ============================================
  void _dibujarMarcadoresPuntos() {
    _markers.removeWhere((m) => m.markerId.value.startsWith("p_"));

    for (int i = 0; i < _puntos.length; i++) {
      final p = _puntos[i];

      final hue = i == 0
          ? BitmapDescriptor.hueGreen
          : (i == _puntos.length - 1
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueRose);

      _markers.add(
        Marker(
          markerId: MarkerId("p_${p.idPunto}"),
          position: LatLng(p.latitud, p.longitud),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: "#${p.orden} - ${p.cliente.nombres}",
            snippet: p.direccion,
          ),
        ),
      );
    }
    setState(() {});
  }

  // ============================================
  // Seguimiento con filtros anti-falsos positivos
  // ============================================
  Future<void> _iniciarSeguimientoTiempoReal() async {
    if (_puntos.isEmpty) return;

    _posSub?.cancel();

    bool procesandoLlegada = false;
    final puntosVisitados = <int>{};

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 4,
      ),
    ).listen((pos) async {
      _posicionActual = LatLng(pos.latitude, pos.longitude);
      _actualizarMarcadorYo();

      if (_puntoActual == null || procesandoLlegada) return;

      final destino =
          LatLng(_puntoActual!.latitud, _puntoActual!.longitud);

      final distancia = Geolocator.distanceBetween(
        _posicionActual!.latitude,
        _posicionActual!.longitude,
        destino.latitude,
        destino.longitude,
      );

      // --- Llegada al punto ---
      if (distancia < 40 && !puntosVisitados.contains(_puntoActual!.idPunto)) {
        procesandoLlegada = true;
        puntosVisitados.add(_puntoActual!.idPunto);
        await _onLlegadaAPunto(_puntoActual!);
        procesandoLlegada = false;
        return;
      }

      // --- Detectar desvío con filtro ---
      if (_polylinePoints.isNotEmpty) {
        final dMin = _distanciaMinimaAPolyline(
          _posicionActual!,
          _polylinePoints,
        );

        _pushDesvioBuffer(dMin);

        if (_esDesvioConfirmado()) {
          _posSub?.pause();
          await _mostrarModalDesvio();
          _posSub?.resume();
          return;
        }
      }

      _primerInicio = false;
    });
  }

  // FILTRO ANTI-FALSOS POSITIVOS
  void _pushDesvioBuffer(double d) {
    _historialDesvio.add(d);
    if (_historialDesvio.length > _minLecturasConfirmar) {
      _historialDesvio.removeAt(0);
    }
  }

  bool _esDesvioConfirmado() {
    if (_primerInicio) return false;
    if (_historialDesvio.length < _minLecturasConfirmar) return false;

    // Suavizado: promedio vs último valor
    final promedio = _historialDesvio.reduce((a, b) => a + b) /
        _historialDesvio.length;

    // Umbral dinámico
    const umbral = 60;

    return promedio > umbral;
  }

  // Distancia más corta a polyline
  double _distanciaMinimaAPolyline(
      LatLng p, List<LatLng> polyline) {
    double minDist = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        polyline[i].latitude,
        polyline[i].longitude,
      );
      if (d < minDist) minDist = d;
    }

    return minDist;
  }

  // ============================================
  // Modal desvío + registro + recalcular
  // ============================================
Future<void> _mostrarModalDesvio() async {
  if (!mounted) return;

  String? motivo = await showDialog<String>(
    context: context,
    barrierDismissible: false, // ❗ evita cerrar con tap afuera
    builder: (_) => WillPopScope(
      onWillPop: () async => false, // ❗ evita cerrar con atrás
      child: AlertDialog(
        title: const Text("Desvío detectado"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Te alejaste de la ruta. ¿Cuál fue el motivo?"),
            for (final m in [
              "Calle cerrada",
              "Mucho tráfico",
              "Desvío por obras",
              "Otro",
            ])
              ListTile(
                title: Text(m),
                onTap: () => Navigator.pop(context, m),
              )
          ],
        ),
      ),
    ),
  );

  // Si no selecciona nada (teóricamente no debería pasar)
  if (motivo == null) {
    _historialDesvio.clear();
    return;
  }

  if (_idRuta != null && _posicionActual != null) {
    await _api.registrarDesvio(
      idRuta: _idRuta!,
      motivo: motivo,
      lat: _posicionActual!.latitude,
      lng: _posicionActual!.longitude,
    );

    _toast("Desvío registrado: $motivo");

    _markers.add(
      Marker(
        markerId: MarkerId(
          "desvio_${DateTime.now().millisecondsSinceEpoch}",
        ),
        position: _posicionActual!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: "Desvío: $motivo"),
      ),
    );
  }

  // Recalcular ruta
  if (_puntoActual != null) {
    await _trazarRuta(
      _posicionActual!,
      LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
    );
  }

  _historialDesvio.clear();
}


  // ============================================
  // Llegada a un punto
  // ============================================
  Future<void> _onLlegadaAPunto(PuntoRutaDet punto) async {
    _toast("Llegaste a ${punto.cliente.nombres}");

    try {
      if (_idRuta != null) {
        await _api.marcarPuntoVisitado(
          idRuta: _idRuta!,
          idPunto: punto.idPunto,
        );
      }
    } catch (_) {
      _toast("No pude marcar punto como visitado");
    }

    if (_indexActual < _puntos.length - 1) {
      setState(() => _indexActual++);

      await _trazarRuta(
        _posicionActual!,
        LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
      );
      await _centrarEnRuta(_posicionActual!, _puntoActual!);
    } else {
      if (_idRuta != null) {
        await _api.actualizarEstadoRuta(idRuta: _idRuta!, estado: false);
      }
      _toast("Ruta terminada");
      if (mounted) Navigator.pop(context);
    }
  }

  // ============================================
  // Trazar ruta (ORS)
  // ============================================
  Future<void> _trazarRuta(LatLng origen, LatLng destino) async {
    try {
      final pts = await _api.trazarRutaEvitarDesvios(
        origen: origen,
        destino: destino,
      );

      _polylinePoints = pts;

      _polylines
        ..removeWhere((p) => p.polylineId == const PolylineId("nav"))
        ..add(
          Polyline(
            polylineId: const PolylineId("nav"),
            points: pts,
            width: 6,
            color: Colors.blue,
          ),
        );

      setState(() {});
    } catch (e) {
      _toast("Error al trazar ruta: $e");
    }
  }

  // ============================================
  // Ajustar cámara
  // ============================================
  Future<void> _centrarEnRuta(
      LatLng origen, PuntoRutaDet destino) async {
    if (!_mapController.isCompleted) return;

    final ctrl = await _mapController.future;

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
      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 96),
      );
    } catch (_) {}
  }

  // ============================================
  // UI
  // ============================================
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                  onMapCreated: (c) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(c);
                    }
                  },
                ),

                if (_puntoActual != null)
                  Positioned(
                    top: 28,
                    left: 12,
                    right: 12,
                    child: _panelInfo(),
                  ),
              ],
            ),
    );
  }

  Widget _panelInfo() {
    final p = _puntoActual!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Orden: ${p.orden}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Código: ${p.cliente.codigo}"),
          Text("Cliente: ${p.cliente.nombres}"),
          Text("Giro: ${p.cliente.giro}"),
          Text("Dirección: ${p.direccion}"),
        ],
      ),
    );
  }
}
