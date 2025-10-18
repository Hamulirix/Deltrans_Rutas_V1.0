class ClienteInfo {
  final String nombres;
  final String giro;
  final String codigo;

  ClienteInfo({required this.nombres, required this.giro, required this.codigo});

  factory ClienteInfo.fromJson(Map<String, dynamic> j) =>
      ClienteInfo(nombres: j['nombres'], giro: j['giro'], codigo: j['codigo']);
}

class PuntoRutaDet {
  final int idPunto;
  final int orden;
  final bool visitado;
  final String direccion;
  final double latitud;
  final double longitud;
  final ClienteInfo cliente;

  PuntoRutaDet({
    required this.idPunto,
    required this.orden,
    required this.visitado,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.cliente,
  });

  factory PuntoRutaDet.fromJson(Map<String, dynamic> j) => PuntoRutaDet(
        idPunto: j['id_punto'],
        orden: j['orden'],
        visitado: j['visitado'] == true,
        direccion: j['direccion'],
        latitud: (j['latitud'] as num).toDouble(),
        longitud: (j['longitud'] as num).toDouble(),
        cliente: ClienteInfo.fromJson(j['cliente']),
      );
}

class RutaConPuntos {
  final int idRuta;
  final int nPuntos;
  final String fecha; // "YYYY-MM-DD"
  final String placa;
  final List<PuntoRutaDet> puntos;

  RutaConPuntos({
    required this.idRuta,
    required this.nPuntos,
    required this.fecha,
    required this.placa,
    required this.puntos,
  });

  factory RutaConPuntos.fromJson(Map<String, dynamic> j) => RutaConPuntos(
        idRuta: j['id_ruta'],
        nPuntos: j['n_puntos'],
        fecha: j['fecha'],
        placa: j['placa'],
        puntos: (j['puntos'] as List)
            .cast<Map<String, dynamic>>()
            .map(PuntoRutaDet.fromJson)
            .toList(),
      );
}
