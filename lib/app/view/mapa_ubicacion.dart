import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 🌍 Página genérica que puede mostrar una o varias ubicaciones.
/// Se usa tanto en Gestionar Incidencias como en Gestionar Rutas.
class MapaUbicacionPage extends StatelessWidget {
  final String titulo;
  final List<LatLng> puntos;
  final String? descripcion;

  const MapaUbicacionPage({
    super.key,
    required this.titulo,
    required this.puntos,
    this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = puntos.isNotEmpty
        ? puntos.first
        : const LatLng(-12.0464, -77.0428); // Lima por defecto

    final markers = <Marker>{};
    if (puntos.isNotEmpty) {
      for (int i = 0; i < puntos.length; i++) {
        markers.add(Marker(
          markerId: MarkerId('punto_$i'),
          position: puntos[i],
          infoWindow: InfoWindow(
            title: (puntos.length == 1)
                ? titulo
                : (i == 0)
                    ? 'Inicio'
                    : (i == puntos.length - 1)
                        ? 'Fin'
                        : 'Punto ${i + 1}',
            snippet: descripcion,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            (i == 0)
                ? BitmapDescriptor.hueGreen
                : (i == puntos.length - 1)
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueAzure,
          ),
        ));
      }
    }

    final polylines = puntos.length > 1
        ? {
            Polyline(
              polylineId: const PolylineId('ruta'),
              points: puntos,
              color: Colors.blue,
              width: 4,
            ),
          }
        : <Polyline>{};

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: inicial, zoom: 15),
        markers: markers,
        polylines: polylines,
        zoomControlsEnabled: true,
        mapType: MapType.normal,
      ),
    );
  }
}
