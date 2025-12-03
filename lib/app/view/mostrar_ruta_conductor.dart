// mostrar_ruta_conductor.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_application_1/app/services/api_service.dart';

/// Una muestra de posible desvío
class _DesvioSample {
  final LatLng pos;
  final double dist; // distancia mínima al polyline (m)
  final DateTime ts;

  _DesvioSample(this.pos, this.dist, this.ts);
}

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

  bool _cargando = true;
  bool _primerInicio = true;

  int? _idRuta;
  List<PuntoRutaDet> _puntos = [];
  int _indexActual = 0;

  PuntoRutaDet? get _puntoActual =>
      (_indexActual >= 0 && _indexActual < _puntos.length)
          ? _puntos[_indexActual]
          : null;

  LatLng? _posicionActual;

  /// polyline actual (ORS)
  List<LatLng> _polylinePoints = [];

  /// Buffer para detectar desvíos suavizados
  final List<_DesvioSample> _bufferDesvio = [];
  static const int _bufferSize = 8;
  static const int _minLecturasConfirmar = 4;
  static const double _umbralDesvioMetros = 50.0;

  /// Punto donde realmente se detectó el desvío
  LatLng? _posicionDesvioDetectada;

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

        // marcadores de desvíos existentes
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
      if (!ok) return;

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
  // Ubicación del usuario
  // ============================================
  Future<bool> _asegurarUbicacionActiva() async {
    try {
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

      LocationPermission perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        _toast("La app no tiene permisos de ubicación.");
        return false;
      }

      if (perm == LocationPermission.denied) {
        _toast("No otorgaste permisos de ubicación.");
        return false;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        _posicionActual = LatLng(pos.latitude, pos.longitude);
        _actualizarMarcadorYo();
        return true;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _posicionActual = LatLng(pos.latitude, pos.longitude);
          _actualizarMarcadorYo();
          return true;
        } catch (_) {
          _toast("No se pudo obtener tu ubicación.");
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
  // Marcadores de puntos de la ruta
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
  // Seguimiento en tiempo real
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

      // Llegada a punto
      if (distancia < 40 && !puntosVisitados.contains(_puntoActual!.idPunto)) {
        procesandoLlegada = true;
        puntosVisitados.add(_puntoActual!.idPunto);
        await _onLlegadaAPunto(_puntoActual!);
        procesandoLlegada = false;
        return;
      }

      // Detectar desvío usando el polyline existente (NO llamamos ORS aquí)
      if (_polylinePoints.length > 1) {
        final dMin = _distanciaMinimaAPolyline(
          _posicionActual!,
          _polylinePoints,
        );

        _registrarSampleDesvio(_posicionActual!, dMin);

        if (_esDesvioConfirmado() &&
            _posicionDesvioDetectada == null) {
          // tomamos la PRIMERA muestra fuera de la ruta
          _DesvioSample? cand;
          for (final s in _bufferDesvio) {
            if (s.dist > _umbralDesvioMetros) {
              cand = s;
              break;
            }
          }
          cand ??= _bufferDesvio.isNotEmpty ? _bufferDesvio.last : null;

          if (cand != null) {
            _posicionDesvioDetectada = cand.pos;
            _posSub?.pause();
            await _mostrarModalDesvio();
            _posSub?.resume();
            return;
          }
        }
      }

      _primerInicio = false;
    });
  }

  // Registrar muestra en el buffer
  void _registrarSampleDesvio(LatLng pos, double dist) {
    _bufferDesvio.add(_DesvioSample(pos, dist, DateTime.now()));
    if (_bufferDesvio.length > _bufferSize) {
      _bufferDesvio.removeAt(0);
    }
  }

  bool _esDesvioConfirmado() {
    if (_primerInicio) return false;
    if (_bufferDesvio.length < _minLecturasConfirmar) return false;

    final ultimos = _bufferDesvio.sublist(
      _bufferDesvio.length - _minLecturasConfirmar,
    );
    final promedio =
        ultimos.map((s) => s.dist).reduce((a, b) => a + b) / ultimos.length;

    return promedio > _umbralDesvioMetros;
  }

double _distanciaMinimaAPolyline(LatLng p, List<LatLng> pts) {
  double minDist = double.infinity;

  for (int i = 0; i < pts.length - 1; i++) {
    final A = pts[i];
    final B = pts[i + 1];

    final d = _distanceToSegmentMeters(p, A, B);

    if (d < minDist) minDist = d;
  }

  return minDist;
}

/// Distancia desde punto P al segmento AB (en metros)
double _distanceToSegmentMeters(LatLng P, LatLng A, LatLng B) {
  // Convertimos a coordenadas planas (aprox local)
  final lat1 = A.latitude * math.pi / 180;
  final lon1 = A.longitude * math.pi / 180;
  final lat2 = B.latitude * math.pi / 180;
  final lon2 = B.longitude * math.pi / 180;
  final latP = P.latitude * math.pi / 180;
  final lonP = P.longitude * math.pi / 180;

  // vectores
  final AtoB_lat = lat2 - lat1;
  final AtoB_lon = lon2 - lon1;
  final AtoP_lat = latP - lat1;
  final AtoP_lon = lonP - lon1;

  // Proyección escalar
  final ab2 = AtoB_lat * AtoB_lat + AtoB_lon * AtoB_lon;
  double t = 0;
  if (ab2 > 0) {
    t = (AtoP_lat * AtoB_lat + AtoP_lon * AtoB_lon) / ab2;
    t = t.clamp(0.0, 1.0);
  }

  // Punto proyectado
  final projLat = lat1 + t * AtoB_lat;
  final projLon = lon1 + t * AtoB_lon;

  // Distancia desde P a la proyección
  return Geolocator.distanceBetween(
    P.latitude,
    P.longitude,
    projLat * 180 / math.pi,
    projLon * 180 / math.pi,
  );
}


  // ============================================
  // Modal y registro del desvío
  // ============================================
Future<void> _mostrarModalDesvio() async {
  if (!mounted) return;

  // 1) Elegir motivo
  String? motivo = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text("Desvío detectado"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Selecciona el motivo del desvío"),
            for (final m in [
              "Calle cerrada",
              "Mucho tráfico",
              "Desvío por obras",
              "Otro",
            ])
              ListTile(
                title: Text(m),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    ),
  );

  if (motivo == null) {
    _bufferDesvio.clear();
    _posicionDesvioDetectada = null;
    return;
  }

  // 🔥 2) Seleccionar punto exacto tocando el mapa
  final puntoMarcado = await _seleccionarPuntoEnMapa();

  if (puntoMarcado == null) {
    _toast("No se seleccionó un punto.");
    return;
  }

  // 🔥 3) Validar que está sobre el polyline
  final distancia = _distanciaMinimaAPolyline(puntoMarcado, _polylinePoints);

  if (distancia > 20) {
    _toast("Debes marcar un punto dentro de la ruta.");
    return;
  }

  // 🔥 4) Registrar desvío con punto marcado
  if (_idRuta != null) {
    await _api.registrarDesvio(
      idRuta: _idRuta!,
      motivo: motivo,
      lat: puntoMarcado.latitude,
      lng: puntoMarcado.longitude,
    );
  }

  _toast("Desvío registrado exitosamente");

  // Marcador visual
  _markers.add(
    Marker(
      markerId: MarkerId("desvio_${DateTime.now().millisecondsSinceEpoch}"),
      position: puntoMarcado,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(title: "Desvío: $motivo"),
    ),
  );

  // Reiniciar buffers
  _bufferDesvio.clear();
  _posicionDesvioDetectada = null;

  // 🔥 Retrazar ruta sin recargar toda la pantalla
  if (_posicionActual != null && _puntoActual != null) {
    await _trazarRuta(
      _posicionActual!,
      LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
    );
  }

  setState(() {});
}

Future<LatLng?> _seleccionarPuntoEnMapa() async {
  LatLng? puntoSeleccionado;

  return await showDialog<LatLng>(
    context: context,
    barrierDismissible: false, // No puede cerrar tocando afuera
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async => false, // No puede usar botón atrás
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Marca el punto exacto del incidente"),
              content: SizedBox(
                width: 350,
                height: 450,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _posicionActual!,
                    zoom: 17,
                  ),
                  polylines: _polylines,
                  markers: puntoSeleccionado != null
                      ? {
                          Marker(
                            markerId: const MarkerId("seleccion"),
                            position: puntoSeleccionado!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          )
                        }
                      : {},
                  onTap: (pos) {
                    setStateDialog(() {
                      puntoSeleccionado = pos;
                    });
                  },
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (puntoSeleccionado == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Selecciona un punto en el mapa."),
                        ),
                      );
                      return;
                    }

                    // Validar distancia al polyline
                    final distancia = _distanciaMinimaAPolyline(
                      puntoSeleccionado!,
                      _polylinePoints,
                    );

                    if (distancia > 20) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Debes marcar un punto dentro de la ruta.",
                          ),
                        ),
                      );
                      return; 
                    }

                    // Punto válido, cerrar y devolverlo
                    Navigator.pop(context, puntoSeleccionado);
                  },
                  child: const Text("Aceptar"),
                ),
              ],
            );
          },
        ),
      );
    },
  );
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

      if (_posicionActual != null) {
        await _trazarRuta(
          _posicionActual!,
          LatLng(_puntoActual!.latitud, _puntoActual!.longitud),
        );
        await _centrarEnRuta(_posicionActual!, _puntoActual!);
      }
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
          Text(
            "Orden: ${p.orden}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text("Código: ${p.cliente.codigo}"),
          Text("Cliente: ${p.cliente.nombres}"),
          Text("Giro: ${p.cliente.giro}"),
          Text("Dirección: ${p.direccion}"),
        ],
      ),
    );
  }
}
