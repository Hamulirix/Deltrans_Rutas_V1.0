import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "http://10.0.2.2:5000/api"; 

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
        return data;
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }

  Future<Map<String, dynamic>> optimizeWithExcel(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    if (token == null) throw Exception("No autenticado");

    final uri = Uri.parse("$baseUrl/optimize");
    final request = http.MultipartRequest("POST", uri);

    // OJO: tu backend espera el token sin "Bearer "
    request.headers["Authorization"] = token;

    request.fields["sheet_name"] = "Hoja1";
    request.fields["deposito_latitude"] = "-6.7604792";
    request.fields["deposito_longitude"] = "-79.8707004";
    request.fields["vehiculo_capacidad"] = "100";
    request.fields["objetivo"] = "distancia";
    request.fields["speed_kmh"] = "30";

    request.files.add(await http.MultipartFile.fromPath(
      "file",
      file.path,
      contentType: MediaType(
        "application",
        "vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      ),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Error ${response.statusCode}: ${response.body}");
    }
  }

  /// 🔹 Guarda rutas optimizadas en el backend
  /// Espera un payload con forma: { "resultados": [ { "placa": "...", "rutas": [ { "nombre": "...", "puntos": [...] } ] } ] }
  Future<Map<String, dynamic>> guardarRutas(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    if (token == null) throw Exception("No autenticado");

    final resp = await http.post(
      Uri.parse("$baseUrl/guardar-rutas"),
      headers: {
        "Content-Type": "application/json",
        // OJO: tu backend espera el token sin "Bearer "
        "Authorization": token,
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception("Error ${resp.statusCode}: ${resp.body}");
    }
  }
}
