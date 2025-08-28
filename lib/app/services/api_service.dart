import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://10.0.2.2:5000/api"; 
  // ⚠️ Cambia a tu IP local si pruebas en celular físico (ej: http://192.168.1.10:5000/api)

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Error de conexión: $e");
    }
  }
}
