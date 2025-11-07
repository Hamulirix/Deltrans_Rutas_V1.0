// api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
/// Excepción HTTP legible
class ApiException extends HttpException {
  final int? statusCode;
  ApiException(super.message, {this.statusCode});

  @override
  String toString() => ' $message';
}

/// =============================
/// Modelos y DTOs
/// =============================

class Usuario {
  final int idUsuario;
  final String username;
  final String nombres;
  final String apellidos;
  final String dni;
  final String tipoTrabajador; // nombre_tipo
  final String estado; // "Activo" | "Inactivo"
  bool get estaActivo => estado.toLowerCase() == 'activo';

  Usuario({
    required this.idUsuario,
    required this.username,
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.tipoTrabajador,
    required this.estado,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    idUsuario: j['id_usuario'],
    username: j['username'],
    nombres: j['nombres'],
    apellidos: j['apellidos'],
    dni: j['dni'],
    tipoTrabajador: j['tipo_trabajador'],
    estado: j['estado'],
  );
}

class UsuarioDetalle {
  final int idUsuario;
  final String username;
  final bool estado;
  final String nombres;
  final String apellidos;
  final String dni;
  final int? idCamion;
  final int idTipoTrabajador;
  final String nombreTipo;

  UsuarioDetalle({
    required this.idUsuario,
    required this.username,
    required this.estado,
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.idTipoTrabajador,
    required this.nombreTipo,
    this.idCamion,
  });

  factory UsuarioDetalle.fromJson(Map<String, dynamic> j) => UsuarioDetalle(
    idUsuario: j['id_usuario'],
    username: j['username'],
    estado: j['estado'] == true || j['estado'] == 1,
    nombres: j['nombres'],
    apellidos: j['apellidos'],
    dni: j['dni'],
    idCamion: j['id_camion'],
    idTipoTrabajador: j['id_tipo_trabajador'],
    nombreTipo: j['nombre_tipo'],
  );
}

class TipoTrabajador {
  final int id;
  final String nombre;
  TipoTrabajador({required this.id, required this.nombre});
  factory TipoTrabajador.fromJson(Map<String, dynamic> j) =>
      TipoTrabajador(id: j['id_tipo_trabajador'], nombre: j['nombre_tipo']);
}

class UsuarioUpdateDto {
  final String nombres;
  final String apellidos;
  final String dni;
  final int? idCamion; // null permitido
  final int idTipoTrabajador;
  final String username;
  final String? password; // opcional
  final bool? estado; // opcional

  UsuarioUpdateDto({
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.idTipoTrabajador,
    required this.username,
    this.idCamion,
    this.password,
    this.estado,
  });

  Map<String, dynamic> toJson() => {
    'nombres': nombres,
    'apellidos': apellidos,
    'dni': dni,
    'id_camion': idCamion, // puede ser null
    'id_tipo_trabajador': idTipoTrabajador,
    'username': username,
    if (password != null && password!.isNotEmpty) 'password': password,
    if (estado != null) 'estado': estado,
  };
}

class UsuarioCreateDto {
  final String nombres;
  final String apellidos;
  final String dni;
  final int idTipoTrabajador;
  final String username;
  final String password; // requerido para crear
  final int? idCamion; // opcional
  final bool estado; // por defecto true

  UsuarioCreateDto({
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.idTipoTrabajador,
    required this.username,
    required this.password,
    this.idCamion,
    this.estado = true,
  });

  Map<String, dynamic> toJson() => {
    "nombres": nombres,
    "apellidos": apellidos,
    "dni": dni,
    "id_tipo_trabajador": idTipoTrabajador,
    "id_camion": idCamion,
    "username": username,
    "password": password,
    "estado": estado,
  };
}

class Camion {
  final int idCamion;
  final String placa;
  final String modelo;
  final String marca;
  final int? capacidadMax; // 👈 puede venir nulo
  final String estado;

  bool get disponible => estado.toLowerCase().startsWith('disponible');

  Camion({
    required this.idCamion,
    required this.placa,
    required this.modelo,
    required this.marca,
    this.capacidadMax,
    required this.estado,
  });

  factory Camion.fromJson(Map<String, dynamic> json) => Camion(
    idCamion: int.tryParse(json['id_camion']?.toString() ?? '') ?? 0,
    placa: json['placa'] ?? '',
    modelo: json['modelo'] ?? '',
    marca: json['marca'] ?? '',
    capacidadMax: json['capacidad_max'] != null
        ? int.tryParse(json['capacidad_max'].toString())
        : null,
    estado: json['estado'] ?? '',
  );
}

class CamionCreateDto {
  final String placa;
  final String modelo;
  final String marca;
  final int capacidadMax;
  final bool estado;

  CamionCreateDto({
    required this.placa,
    required this.modelo,
    required this.marca,
    required this.capacidadMax,
    this.estado = true,
  });

  Map<String, dynamic> toJson() => {
    'placa': placa,
    'modelo': modelo,
    'marca': marca,
    'capacidad_max': capacidadMax,
    'estado': estado,
  };
}

class CamionUpdateDto {
  final String placa;
  final String modelo;
  final String marca;
  final int capacidadMax;
  final bool estado;

  CamionUpdateDto({
    required this.placa,
    required this.modelo,
    required this.marca,
    required this.capacidadMax,
    required this.estado,
  });

  Map<String, dynamic> toJson() => {
    'placa': placa,
    'modelo': modelo,
    'marca': marca,
    'capacidad_max': capacidadMax,
    'estado': estado,
  };
}

// --- MODELO ---
class RutaResumen {
  final int idRuta;
  final String? fecha;
  final int nPuntos;
  final String? primerPunto;
  final String? ultimoPunto;
  final int estado;
  final String? placa;

  RutaResumen({
    required this.idRuta,
    required this.fecha,
    required this.nPuntos,
    required this.primerPunto,
    required this.ultimoPunto,
    required this.estado,
    required this.placa,
  });

  factory RutaResumen.fromJson(Map<String, dynamic> j) => RutaResumen(
    idRuta: j['id_ruta'] is int
        ? j['id_ruta']
        : int.tryParse(j['id_ruta']?.toString() ?? '') ?? 0,
    fecha: j['fecha']?.toString(), // puede venir null
    nPuntos: j['n_puntos'] is int
        ? j['n_puntos']
        : int.tryParse(j['n_puntos']?.toString() ?? '') ?? 0,
    primerPunto: j['primer_punto']?.toString(),
    ultimoPunto: j['ultimo_punto']?.toString(),
    estado: j['estado'] is int
        ? j['estado']
        : int.tryParse(j['estado']?.toString() ?? '') ?? 0,
    placa: j['placa']?.toString(),
  );
}

class PuntoRuta {
  final int idPunto;
  final int numero;
  final String direccion;
  final double lat;
  final double lng;
  final bool visitado;

  PuntoRuta({
    required this.idPunto,
    required this.numero,
    required this.direccion,
    required this.lat,
    required this.lng,
    required this.visitado,
  });

  factory PuntoRuta.fromJson(Map<String, dynamic> j) => PuntoRuta(
    idPunto: j['id_ruta_punto'],
    numero: j['numero'],
    direccion: j['direccion'],
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    visitado: j['visitado'] == true,
  );
}

class ClienteInfo {
  final String nombres;
  final String giro;
  final String codigo;

  ClienteInfo({
    required this.nombres,
    required this.giro,
    required this.codigo,
  });

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

class Desvio {
  final int idDesvio;
  final String motivo;
  final double lat;
  final double lng;
  final double? latMin;
  final double? latMax;
  final double? lngMin;
  final double? lngMax;
  final String estado;

  Desvio({
    required this.idDesvio,
    required this.motivo,
    required this.lat,
    required this.lng,
    this.latMin,
    this.latMax,
    this.lngMin,
    this.lngMax,
    required this.estado,
  });

  factory Desvio.fromJson(Map<String, dynamic> j) => Desvio(
        idDesvio: j['id_desvio'] ?? 0,
        motivo: j['motivo'] ?? '',
        lat: (j['latitud'] as num).toDouble(),
        lng: (j['longitud'] as num).toDouble(),
        latMin: j['lat_min'] != null ? (j['lat_min'] as num).toDouble() : null,
        latMax: j['lat_max'] != null ? (j['lat_max'] as num).toDouble() : null,
        lngMin: j['lng_min'] != null ? (j['lng_min'] as num).toDouble() : null,
        lngMax: j['lng_max'] != null ? (j['lng_max'] as num).toDouble() : null,
        estado: j['estado']?.toString() ?? 'Desconocido',
      );
}




class ApiService {

  final String baseUrl =
      "https://craftiest-malodorous-tandra.ngrok-free.dev/api"; 


  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token");
  }

  Future<Map<String, String>> _jsonHeaders({bool withAuth = true}) async {
    final headers = <String, String>{"Content-Type": "application/json"};
    if (withAuth) {
      final token = await _getToken();
      if (token == null) throw ApiException("No autenticado");

      headers["Authorization"] = token;
    }
    return headers;
  }

  dynamic _decodeBody(http.Response resp) {
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return resp.body;
    }
  }

  T _handleResponse<T>(http.Response resp, T Function(dynamic json) parser) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _decodeBody(resp);
      return parser(data);
    } else {
      final data = _decodeBody(resp);
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Error ${resp.statusCode}: ${resp.body}';
      throw ApiException(message, statusCode: resp.statusCode);
    }
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", data["access_token"]);
        return data as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      throw ApiException("Error de conexión: $e");
    }
  }

  Future<int> obtenerTotalRutas() async {
    final url = Uri.parse('$baseUrl/reportes/total-rutas');
    final resp = await http.get(url, headers: await _jsonHeaders());

    return _handleResponse<int>(resp, (json) {
      if (json is Map && json['total_rutas'] != null) {
        final v = json['total_rutas'];
        return v is int ? v : int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    });
  }

  /// Optimización con Excel (sin prioridad_giro)
  Future<Map<String, dynamic>> optimizeWithExcel({required File file}) async {
    final token = await _getToken();
    if (token == null) throw ApiException("No autenticado");

    final uri = Uri.parse("$baseUrl/optimize");
    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = token;

    // Campos requeridos por tu backend
    request.fields["sheet_name"] = "Hoja1";

    // Archivo Excel
    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        file.path,
        contentType: MediaType(
          "application",
          "vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    return _handleResponse<Map<String, dynamic>>(
      response,
      (json) => json as Map<String, dynamic>,
    );
  }

  /// Guarda rutas optimizadas en el backend
  Future<Map<String, dynamic>> guardarRutas(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse("$baseUrl/guardar-rutas");
    final headers = await _jsonHeaders(withAuth: true); // token_required activo

    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      // convierte a ApiException con mensaje claro
      final data = _decodeBody(resp);
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Sesión expirada o no autorizada';
      throw ApiException(msg, statusCode: resp.statusCode);
    }

    return _handleResponse<Map<String, dynamic>>(
      resp,
      (json) => json as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>?> recalcularRuta(
    List<Map<String, double>> puntos,
  ) async {
    try {
      final url = Uri.parse("$baseUrl/recalcular_ruta");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"puntos": puntos}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// =============================
  /// USUARIOS
  /// =============================

  Future<List<Usuario>> listarUsuarios() async {
    final resp = await http.get(
      Uri.parse("$baseUrl/usuarios"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<List<Usuario>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list.map(Usuario.fromJson).toList();
    });
  }

  Future<Map<String, dynamic>> registrarUsuario(UsuarioCreateDto dto) async {
    final resp = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: await _jsonHeaders(), // incluye Authorization sin "Bearer "
      body: jsonEncode(dto.toJson()),
    );
    return _handleResponse<Map<String, dynamic>>(
      resp,
      (json) => json as Map<String, dynamic>,
    );
  }

  Future<String> eliminarUsuario(int idUsuario) async {
    final resp = await http.delete(
      Uri.parse("$baseUrl/usuarios/$idUsuario"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<String>(resp, (json) {
      if (json is Map && json['message'] != null) return json['message'];
      return 'OK';
    });
  }

  Future<String> actualizarUsuario(int idUsuario, UsuarioUpdateDto data) async {
    final resp = await http.put(
      Uri.parse("$baseUrl/usuarios/$idUsuario"),
      headers: await _jsonHeaders(),
      body: jsonEncode(data.toJson()),
    );
    return _handleResponse<String>(resp, (json) {
      if (json is Map && json['message'] != null) return json['message'];
      return 'Usuario actualizado';
    });
  }

  Future<UsuarioDetalle> obtenerUsuarioDetalle(int idUsuario) async {
    final resp = await http.get(
      Uri.parse("$baseUrl/usuarios/$idUsuario"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<UsuarioDetalle>(
      resp,
      (json) => UsuarioDetalle.fromJson(json),
    );
  }

  Future<List<TipoTrabajador>> listarTiposTrabajador() async {
    final resp = await http.get(
      Uri.parse("$baseUrl/tipos-trabajador"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<List<TipoTrabajador>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list.map(TipoTrabajador.fromJson).toList();
    });
  }

  Future<List<Camion>> listarCamionesDisponibles({int? includeId}) async {
    final uri = includeId == null
        ? Uri.parse("$baseUrl/camiones/disponibles")
        : Uri.parse("$baseUrl/camiones/disponibles?include_id=$includeId");

    final resp = await http.get(uri, headers: await _jsonHeaders());
    return _handleResponse<List<Camion>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list.map(Camion.fromJson).toList();
    });
  }

  /// =============================
  /// CAMIONES (CRUD)
  /// =============================

  Future<List<Camion>> listarCamiones() async {
    final resp = await http.get(
      Uri.parse("$baseUrl/camiones"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<List<Camion>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list.map(Camion.fromJson).toList();
    });
  }

  /// Devuelve un pequeño “ref” con id_camion y placa desde la respuesta 201
  Future<Map<String, dynamic>> crearCamion(CamionCreateDto data) async {
    final resp = await http.post(
      Uri.parse("$baseUrl/camiones"),
      headers: await _jsonHeaders(),
      body: jsonEncode(data.toJson()),
    );
    return _handleResponse<Map<String, dynamic>>(resp, (json) {
      return (json as Map<String, dynamic>);
    });
  }

  Future<String> eliminarCamion(int idCamion) async {
    final resp = await http.delete(
      Uri.parse("$baseUrl/camiones/$idCamion"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<String>(resp, (json) {
      if (json is Map && json['message'] != null) return json['message'];
      return 'OK';
    });
  }

  Future<String> actualizarCamion(int idCamion, CamionUpdateDto data) async {
    final resp = await http.put(
      Uri.parse("$baseUrl/camiones/$idCamion"),
      headers: await _jsonHeaders(),
      body: jsonEncode(data.toJson()),
    );
    return _handleResponse<String>(resp, (json) {
      if (json is Map && json['message'] != null) return json['message'];
      return 'Camión actualizado';
    });
  }

  /// =============================
  /// RUTAS
  /// =============================
  ///
  ///

  // =============================
  // Normalizadores (privados)
  // =============================
  Map<String, dynamic> _normalizeRutaResumenJson(Map<String, dynamic> j) {
    final out = Map<String, dynamic>.from(j);

    if (!out.containsKey('n_puntos') && out.containsKey('puntos')) {
      out['n_puntos'] = out['puntos'];
    }
    out['primer_punto'] = out['primer_punto'];
    out['ultimo_punto'] = out['ultimo_punto'];

    // Asegura tipos
    if (out['id_ruta'] is String) {
      out['id_ruta'] = int.tryParse(out['id_ruta']) ?? 0;
    }
    if (out['n_puntos'] is String) {
      out['n_puntos'] = int.tryParse(out['n_puntos']) ?? 0;
    }
    // 'fecha' puede ser null o String; no tocamos el formato aquí
    return out;
  }

  Future<List<RutaResumen>> listarRutas() async {
    final resp = await http.get(
      Uri.parse("$baseUrl/rutas"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<List<RutaResumen>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list
          .map(_normalizeRutaResumenJson)
          .map(RutaResumen.fromJson)
          .toList();
    });
  }

  Future<List<PuntoRuta>> listarPuntosDeRuta(int idRuta) async {
    final resp = await http.get(
      Uri.parse("$baseUrl/rutas/$idRuta/puntos"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<List<PuntoRuta>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list.map(PuntoRuta.fromJson).toList();
    });
  }

  Future<RutaResumen> obtenerDetalleRuta(int idRuta) async {
    final resp = await http.get(
      Uri.parse("$baseUrl/rutas/$idRuta"),
      headers: await _jsonHeaders(),
    );

    return _handleResponse<RutaResumen>(
      resp,
      (json) => RutaResumen.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<String> eliminarRuta(int idRuta) async {
    final resp = await http.delete(
      Uri.parse("$baseUrl/rutas/$idRuta"),
      headers: await _jsonHeaders(),
    );
    return _handleResponse<String>(resp, (json) {
      if (json is Map && json['message'] != null) return json['message'];
      return 'Ruta dada de baja';
    });
  }

  Future<List<RutaResumen>> listarRutasPorCamion(int idCamion) async {
    final uri = Uri.parse("$baseUrl/camiones/$idCamion/rutas");
    final resp = await http
        .get(uri, headers: await _jsonHeaders())
        .timeout(const Duration(seconds: 12));
    return _handleResponse<List<RutaResumen>>(resp, (json) {
      final list = (json as List).cast<Map<String, dynamic>>();
      return list.map(RutaResumen.fromJson).toList();
    });
  }

  Future<Map<String, dynamic>> actualizarFechaRuta({
    required int idRuta,
    DateTime? fecha, // null = quitar fecha
  }) async {
    final uri = Uri.parse("$baseUrl/rutas/$idRuta/fecha");

    String? fechaStr;
    if (fecha != null) {
      final y = fecha.year.toString().padLeft(4, '0');
      final m = fecha.month.toString().padLeft(2, '0');
      final d = fecha.day.toString().padLeft(2, '0');
      fechaStr = "$y-$m-$d"; // YYYY-MM-DD
    } else {
      fechaStr = null; // explícitamente null para eliminar fecha
    }

    final resp = await http
        .put(
          uri,
          headers:
              await _jsonHeaders(), // incluye Authorization (sin "Bearer ")
          body: jsonEncode({"fecha": fechaStr}),
        )
        .timeout(const Duration(seconds: 12));

    return _handleResponse<Map<String, dynamic>>(
      resp,
      (json) => (json as Map<String, dynamic>),
    );
  }

  Future<int> agregarPuntoARuta({
    required int idRuta,
    required String direccion,
    required double latitud,
    required double longitud,
    required int idCliente,
    int? orden,
  }) async {
    final body = {
      "accion": "agregar",
      "direccion": direccion,
      "latitud": latitud,
      "longitud": longitud,
      "id_cliente": idCliente,
      if (orden != null) "orden": orden,
    };

    final resp = await http.post(
      Uri.parse("$baseUrl/rutas/$idRuta/puntos"),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );

    return _handleResponse<int>(resp, (json) {
      if (json is Map && json['n_puntos'] != null) {
        final v = json['n_puntos'];
        return v is int ? v : int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    });
  }

  Future<int> eliminarPuntoDeRuta({
    required int idRuta,
    required int idRutaPunto,
  }) async {
    final body = {"accion": "eliminar", "id_ruta_punto": idRutaPunto};

    final resp = await http.post(
      Uri.parse("$baseUrl/rutas/$idRuta/puntos"),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );

    return _handleResponse<int>(resp, (json) {
      if (json is Map && json['n_puntos'] != null) {
        final v = json['n_puntos'];
        return v is int ? v : int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    });
  }

  Future<void> reordenarPuntoDeRuta({
    required int idRuta,
    required int idRutaPunto,
    required int nuevoOrden,
  }) async {
    final body = {
      "accion": "reordenar",
      "id_ruta_punto": idRutaPunto,
      "nuevo_orden": nuevoOrden,
    };

    final resp = await http.post(
      Uri.parse("$baseUrl/rutas/$idRuta/puntos"),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );

    _handleResponse<void>(resp, (_) {});
  }

  /// GET /api/rutas/puntos?id_camion=..&fecha=YYYY-MM-DD
  Future<RutaConPuntos> obtenerPuntosRuta({
    required String placa,
    required DateTime fecha,
  }) async {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    final qs = "placa=$placa&fecha=$y-$m-$d";

    final resp = await http.get(
      Uri.parse("$baseUrl/rutas/puntos?$qs"),
      headers: await _jsonHeaders(), // incluye Authorization (tu token JWT)
    );

    return _handleResponse<RutaConPuntos>(
      resp,
      (json) => RutaConPuntos.fromJson(json),
    );
  }

  // Marca un punto como visitado para una ruta
  Future<Map<String, dynamic>> marcarPuntoVisitado({
    required int idRuta,
    required int idPunto,
  }) async {
    final uri = Uri.parse('$baseUrl/ruta-punto/visitar');

    final resp = await http.put(
      uri,
      headers: await _jsonHeaders(withAuth: true),
      body: jsonEncode({'id_ruta': idRuta, 'id_punto': idPunto}),
    );

    return _handleResponse<Map<String, dynamic>>(
      resp,
      (json) => json as Map<String, dynamic>,
    );
  }

  // Cambia el estado de la ruta (true=activa, false=inactiva)
  Future<Map<String, dynamic>> actualizarEstadoRuta({
    required int idRuta,
    required bool estado,
  }) async {
    final uri = Uri.parse('$baseUrl/rutas/$idRuta/estado');

    final resp = await http.put(
      uri,
      headers: await _jsonHeaders(withAuth: true),
      body: jsonEncode({'estado': estado}),
    );

    return _handleResponse<Map<String, dynamic>>(
      resp,
      (json) => json as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> obtenerReportes({
    required int idCamion,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final fi = _fmt(fechaInicio);
    final ff = _fmt(fechaFin);

    final uri = Uri.parse(
      '$baseUrl/reportes?id_camion=$idCamion&fecha_inicio=$fi&fecha_fin=$ff',
    );

    final resp = await http.get(uri, headers: await _jsonHeaders());
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    } else {
      throw ApiException('Error ${resp.statusCode}: ${resp.body}');
    }
  }

  // ✅ ESTE es el método que te faltaba:
  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>?> buscarClientePorCodigo(String codigo) async {
    final codigoTrim = codigo.trim();

    // Opción 1 (simple, clara)
    final uri = Uri.parse(
      '$baseUrl/clientes/buscar?codigo=${Uri.encodeQueryComponent(codigoTrim)}',
    );


    final resp = await http.get(uri, headers: await _jsonHeaders());

    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    } else if (resp.statusCode == 404) {
      return null;
    } else {
      throw ApiException(
        'Error ${resp.statusCode}: ${resp.body}',
        statusCode: resp.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> crearCliente({
    required String codigo,
    required String nombres,
    required String giro,
  }) async {
    final uri = Uri.parse('$baseUrl/clientes');

    final body = json.encode({
      'codigo': codigo.trim(),
      'nombres': nombres.trim(),
      'giro': giro.trim(),
    });

    final resp = await http.post(
      uri,
      headers: await _jsonHeaders(),
      body: body,
    );

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Error ${resp.statusCode}: ${resp.body}',
        statusCode: resp.statusCode,
      );
    }
  }

    /// Registra un desvío detectado durante la ruta del conductor
Future<Map<String, dynamic>> registrarDesvio({
  required int idRuta,
  required String motivo,
  required double lat,
  required double lng,
}) async {
  final uri = Uri.parse("$baseUrl/rutas/$idRuta/desvio");
  final headers = await _jsonHeaders(withAuth: true);

  final body = jsonEncode({
    "motivo": motivo,
    "lat": lat,
    "lng": lng,
  });

  final resp = await http.post(uri, headers: headers, body: body);

  if (resp.statusCode == 401 || resp.statusCode == 403) {
    final data = _decodeBody(resp);
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Sesión expirada o no autorizada';
    throw ApiException(msg, statusCode: resp.statusCode);
  }

  return _handleResponse<Map<String, dynamic>>(
    resp,
    (json) => json as Map<String, dynamic>,
  );
}


    /// 📋 Listar todas las incidencias (desvíos)
  Future<List<Desvio>> listarDesvios() async {
    final uri = Uri.parse("$baseUrl/desvios");
    final headers = await _jsonHeaders(withAuth: true);

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      final data = _decodeBody(resp);
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Sesión expirada o no autorizada';
      throw ApiException(msg, statusCode: resp.statusCode);
    }

    return _handleResponse<List<Desvio>>(
      resp,
      (json) => (json as List)
          .map((e) => Desvio.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 🔻 Dar de baja (estado = 0)
  Future<String> darBajaDesvio(int idDesvio) async {
    final uri = Uri.parse("$baseUrl/desvios/$idDesvio/baja");
    final headers = await _jsonHeaders(withAuth: true);
    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      final data = _decodeBody(resp);
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Sesión expirada o no autorizada';
      throw ApiException(msg, statusCode: resp.statusCode);
    }

    final data = _decodeBody(resp);
    if (resp.statusCode == 200 && data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    throw ApiException('Error al dar de baja el desvío');
  }

  /// ❌ Eliminar físicamente
  Future<String> eliminarDesvio(int idDesvio) async {
    final uri = Uri.parse("$baseUrl/desvios/$idDesvio");
    final headers = await _jsonHeaders(withAuth: true);
    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      final data = _decodeBody(resp);
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Sesión expirada o no autorizada';
      throw ApiException(msg, statusCode: resp.statusCode);
    }

    final data = _decodeBody(resp);
    if (resp.statusCode == 200 && data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    throw ApiException('Error al eliminar el desvío');
  }

Future<List<Desvio>> listarDesviosActivos() async {
  final resp = await http.get(
    Uri.parse("$baseUrl/desvios/activos"),
    headers: await _jsonHeaders(withAuth: false),
  );

  if (resp.statusCode != 200) {
    throw Exception('Error al obtener desvíos activos');
  }

  final List data = jsonDecode(resp.body);
  return data.map((e) => Desvio.fromJson(e)).toList();
}



Future<List<LatLng>> trazarRutaEvitarDesvios({
  required LatLng origen,
  required LatLng destino,
}) async {
  final url = Uri.parse("$baseUrl/rutas/evitar_desvios");

  final resp = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "origen": {"lat": origen.latitude, "lng": origen.longitude},
      "destino": {"lat": destino.latitude, "lng": destino.longitude},
    }),
  );

  if (resp.statusCode != 200) {
    throw Exception('Error al obtener ruta: ${resp.body}');
  }

  final data = jsonDecode(resp.body);
  final List pts = data["ruta"];
  return pts
      .map((p) => LatLng(p["lat"].toDouble(), p["lng"].toDouble()))
      .toList();
}


}
