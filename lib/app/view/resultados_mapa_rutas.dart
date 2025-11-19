import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/buscar_cliente.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_application_1/app/view/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  CameraUpdate? _pendingUpdate;

  String? _rutaSeleccionada;
  Map<String, dynamic>? _resumenSeleccionado;
  String? _placaSeleccionada;

  final List<Map<String, dynamic>> _listaRutas = [];
  bool _modoEditar = false;
  bool _saving = false;
  bool _agregandoPunto = false;

  final Map<String, Map<String, dynamic>> _clientePorCoord = {};

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
    _clientePorCoord.clear();

    for (final p in puntos) {
      final lat = (p["latitude"] as num).toDouble();
      final lng = (p["longitude"] as num).toDouble();
      final pos = LatLng(lat, lng);
      nuevosPuntos.add(pos);

      final key = "$lat,$lng";
      _clientePorCoord[key] = {
        "codigo": (p["codigo"] ?? "").toString(),
        "nombres": (p["cliente"] ?? p["nombres"] ?? "").toString(),
        "giro": (p["giro"] ?? "").toString(),
        "direccion": (p["direccion"] ?? "").toString(),
        "id_cliente": p["id_cliente"],
      };
    }

    setState(() {
      _rutaSeleccionada = ruta["nombre"];
      _resumenSeleccionado = Map<String, dynamic>.from(ruta["resumen"]);
      _placaSeleccionada = ruta["placa"];
      _puntosRuta = nuevosPuntos;
      _polylines = {};
    });

    _rebuildDesdePuntos();
  }

  // =======================
  // Reconstrucción visual
  // =======================
  void _rebuildDesdePuntos() {
    final nuevosMarkers = <Marker>{};
    for (int i = 0; i < _puntosRuta.length; i++) {
      final pos = _puntosRuta[i];
      final icono = (i == 0)
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
          : (i == _puntosRuta.length - 1)
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

      final key = "${pos.latitude},${pos.longitude}";
      final cli = _clientePorCoord[key];
      final snippet =
          (cli != null && (cli["nombres"]?.toString().isNotEmpty ?? false))
          ? "${cli["nombres"]} (${cli["codigo"] ?? "-"})"
          : null;

      nuevosMarkers.add(
        Marker(
          markerId: MarkerId("punto_$i"),
          position: pos,
          infoWindow: InfoWindow(title: "Punto ${i + 1}", snippet: snippet),
          icon: icono,
          onTap: () {
            if (_modoEditar) _mostrarAccionesPunto(i);
          },
        ),
      );
    }

    setState(() => _marcadores = nuevosMarkers);
    _drawRoadPolyline();
  }

  Future<void> _drawRoadPolyline() async {
    // Si hay menos de dos puntos, no generar polyline ni bounds
    if (_puntosRuta.length < 2) {
      setState(() => _polylines = {});
      return;
    }

    // Dibujar polyline
    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('ruta_${_rutaSeleccionada ?? 'x'}'),
          points: _puntosRuta,
          width: 4,
          color: Colors.lightBlue,
        ),
      };
    });

    // 🔹 iOS necesita que el mapa renderice antes de usar bounds
    await Future.delayed(const Duration(milliseconds: 150));

    final bounds = _boundsFromLatLngList(_puntosRuta);

    // 📌 Intentar aplicar los bounds
    final update = CameraUpdate.newLatLngBounds(bounds, 60);
    await _safeAnimateCamera(update);
  }

  Future<void> _safeAnimateCamera(CameraUpdate update) async {
    if (_mapController == null) {
      _pendingUpdate = update;
      return;
    }

    try {
      await _mapController!.animateCamera(update);
    } catch (e) {
      print("⚠ Error aplicando bounds en iOS → fallback: $e");

      // 🔥 fallback seguro: centrar en último punto
      if (_puntosRuta.isNotEmpty) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLng(_puntosRuta.last),
          );
        } catch (_) {}
      }
    }
  }

  // =======================
  // Edición de puntos
  // =======================
  void _eliminarIndice(int index) async {
    if (index < 0 || index >= _puntosRuta.length) return;
    final pos = _puntosRuta[index];
    final key = "${pos.latitude},${pos.longitude}";
    _clientePorCoord.remove(key);

    setState(() {
      _puntosRuta.removeAt(index);
    });
    _rebuildDesdePuntos();
    await _recalcularRuta();
  }

  void _moverPunto(int fromIndex, int toIndex) async {
    if (fromIndex == toIndex) return;
    if (fromIndex < 0 || fromIndex >= _puntosRuta.length) return;
    if (toIndex < 0) toIndex = 0;
    if (toIndex >= _puntosRuta.length) toIndex = _puntosRuta.length - 1;

    final p = _puntosRuta.removeAt(fromIndex);
    _puntosRuta.insert(toIndex, p);

    final oldKey = "${p.latitude},${p.longitude}";
    final cli = _clientePorCoord.remove(oldKey);
    if (cli != null) _clientePorCoord[oldKey] = cli;

    _rebuildDesdePuntos();
    await _recalcularRuta();
  }

  Future<void> _agregarPuntoConCliente(LatLng pos) async {
    final seleccionado = await Navigator.of(context)
        .push<Map<String, dynamic>?>(
          MaterialPageRoute(
            builder: (_) => BuscarClientePage(posicion: pos),
            fullscreenDialog: true,
          ),
        );

    if (seleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación cancelada. No se agregó el punto.'),
        ),
      );
      return;
    }

    String? direccion = seleccionado["direccion"];
    if (direccion == null || direccion.trim().isEmpty) {
      direccion = await _pedirDireccion(context);
      if (direccion == null || direccion.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes ingresar una dirección para agregar el punto.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _puntosRuta.add(pos);
      final key = "${pos.latitude},${pos.longitude}";
      _clientePorCoord[key] = {
        "codigo": seleccionado["codigo"] ?? "",
        "nombres": seleccionado["nombres"] ?? "",
        "giro": seleccionado["giro"] ?? "",
        "id_cliente": seleccionado["id_cliente"],
        "direccion": direccion,
      };
    });

    _rebuildDesdePuntos();
    await _recalcularRuta();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Punto agregado para ${_clientePorCoord["${pos.latitude},${pos.longitude}"]?["nombres"] ?? "cliente"}',
        ),
      ),
    );
  }

  Future<String?> _pedirDireccion(BuildContext context) async {
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

  void _mostrarAccionesPunto(int index) {
    final controller = TextEditingController(text: (index + 1).toString());
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
                "Punto actual: ${index + 1} / ${_puntosRuta.length}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nuevo orden (1..N)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.swap_vert),
                      label: const Text("Aplicar orden"),
                      onPressed: () {
                        final val = int.tryParse(controller.text.trim());
                        if (val == null ||
                            val < 1 ||
                            val > _puntosRuta.length) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Ingresa un número válido."),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _moverPunto(index, val - 1);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Eliminar"),
                      onPressed: () {
                        Navigator.pop(context);
                        _eliminarIndice(index);
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

  Future<void> _recalcularRuta() async {
    if (_puntosRuta.length < 2) return;
    try {
      final puntos = _puntosRuta
          .map((p) => {"latitude": p.latitude, "longitude": p.longitude})
          .toList();

      final result = await ApiService().recalcularRuta(
        (puntos as List).cast<Map<String, double>>(),
      );

      if (result != null && mounted) {
        setState(() {
          _resumenSeleccionado?["distancia_opt_km"] = result["distancia_km"];
          _resumenSeleccionado?["tiempo_opt_hor"] = result["tiempo_horas"];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Ruta recalculada: ${result["distancia_km"]} km, ${result["tiempo_horas"]} h",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al recalcular: $e")));
    }
  }

  Map<String, dynamic> _payloadTodasLasRutas() {
    final resultados = <Map<String, dynamic>>[];

    if (_rutaSeleccionada != null) {
      final rutaActiva = _listaRutas.firstWhere(
        (r) => r["nombre"] == _rutaSeleccionada,
        orElse: () => {},
      );

      if (rutaActiva.isNotEmpty) {
        final nuevosPuntos = _puntosRuta.map((p) {
          final key = "${p.latitude},${p.longitude}";
          final cli = _clientePorCoord[key];
          return {
            "direccion": (cli?["direccion"] ?? "").toString(),
            "latitude": p.latitude,
            "longitude": p.longitude,
            "cliente": (cli?["nombres"] ?? "").toString(),
            "giro": (cli?["giro"] ?? "").toString(),
            "codigo": (cli?["codigo"] ?? "").toString(),
          };
        }).toList();

        rutaActiva["puntos"] = nuevosPuntos;
        rutaActiva["total_puntos"] = nuevosPuntos.length;
      }
    }

    for (final ruta in _listaRutas) {
      final placa = ruta["placa"];
      final nombreRuta = ruta["nombre"];
      final puntosEditados = (ruta["puntos"] as List)
          .cast<Map<String, dynamic>>();

      resultados.add({
        "placa": placa,
        "rutas": [
          {"nombre": nombreRuta, "puntos": puntosEditados},
        ],
      });
    }

    return {"resultados": resultados};
  }

  void _sincronizarRutaActual() {
    if (_rutaSeleccionada == null) return;

    final rutaActiva = _listaRutas.firstWhere(
      (r) => r["nombre"] == _rutaSeleccionada,
      orElse: () => {},
    );

    if (rutaActiva.isEmpty) return;

    final nuevosPuntos = _puntosRuta.map((p) {
      final key = "${p.latitude},${p.longitude}";
      final cli = _clientePorCoord[key];

      return {
        "direccion": (cli?["direccion"] ?? "").toString(),
        "latitude": p.latitude,
        "longitude": p.longitude,
        "cliente": (cli?["nombres"] ?? "").toString(),
        "giro": (cli?["giro"] ?? "").toString(),
        "codigo": (cli?["codigo"] ?? "").toString(),
        "id_cliente": cli?["id_cliente"],
      };
    }).toList();

    rutaActiva["puntos"] = nuevosPuntos;
    rutaActiva["total_puntos"] = nuevosPuntos.length;
  }

  Future<void> _guardarRutas() async {
    if (_listaRutas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay rutas disponibles para guardar.")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = _payloadTodasLasRutas();
      final res = await ApiService().guardarRutas(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Todas las rutas se guardaron correctamente',
          ),
        ),
      );

      // 🔹 Recuperar datos del login guardados en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final nombre = prefs.getString("nombre") ?? "Usuario";
      final rolId = prefs.getInt("id_tipo_trabajador") ?? 1;
      final placa = prefs.getString("placa_camion");

      final rol = (rolId == 1) ? "gerente" : "conductor";

      // 🔹 Volver a Home, en la pestaña correspondiente
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => Home(nombre: nombre, rol: rol, placaCamion: placa),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = (e.statusCode == 401 || e.statusCode == 403)
          ? 'Sesión expirada. Inicia sesión de nuevo.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      floatingActionButton: _modoEditar
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(
                _agregandoPunto ? "Toca el mapa..." : "Agregar punto",
              ),
              onPressed: () {
                setState(() => _agregandoPunto = !_agregandoPunto);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _agregandoPunto
                          ? "Toca el mapa y luego selecciona/crea cliente."
                          : "Agregar punto cancelado.",
                    ),
                  ),
                );
              },
            )
          : null,
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
                    Text(
                      "Camión: ${_placaSeleccionada ?? '-'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Distancia optimizada:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${_resumenSeleccionado!["distancia_opt_km"]} km",
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Distancia original:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${_resumenSeleccionado!["distancia_original_km"]} km",
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Tiempo optimizado:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${_resumenSeleccionado!["tiempo_opt_hor"]} horas",
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Tiempo original:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${_resumenSeleccionado!["tiempo_original_hor"]} horas",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Mejora distancia: ${_resumenSeleccionado!["mejora_distancia_pct"]}%",
                    ),
                    Text(
                      "Mejora tiempo: ${_resumenSeleccionado!["mejora_tiempo_pct"]}%",
                    ),
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
                  child: Text(
                    "Camión: ${ruta["placa"]} - ${ruta["total_puntos"]} puntos",
                  ),
                );
              }).toList(),
              onChanged: (value) {
                // 🔹 Antes de cambiar, guardo la ruta actual
                _sincronizarRutaActual();

                // 🔹 Ahora sí cambio de ruta
                final ruta = _listaRutas.firstWhere(
                  (r) => r["nombre"] == value,
                );
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
                  Future.delayed(const Duration(milliseconds: 100), () async {
                    if (_mapController != null) {
                      try {
                        await _mapController!.animateCamera(_pendingUpdate!);
                      } catch (e) {
                        print("⚠ Error aplicando pendingUpdate: $e");
                      }
                    }
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
              onTap: (pos) {
                if (_modoEditar && _agregandoPunto) {
                  setState(() => _agregandoPunto = false);
                  _agregarPuntoConCliente(pos);
                }
              },
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
                    setState(() {
                      _modoEditar = !_modoEditar;
                      if (!_modoEditar) _agregandoPunto = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _modoEditar
                              ? "Modo edición: usa + para agregar; toca un punto para cambiar orden o eliminar."
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Guardar rutas"),
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
