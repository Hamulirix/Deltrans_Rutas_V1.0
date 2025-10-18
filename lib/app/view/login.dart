import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService api = ApiService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await api.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (result != null && result["access_token"] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", result["access_token"]);

        final rolId = result["trabajador"]["id_tipo_trabajador"] as int;
        await prefs.setInt("id_tipo_trabajador", rolId);

        // Nombre y placa
        final nombreCompleto =
            "${result["trabajador"]["nombres"]} ${result["trabajador"]["apellidos"]}";
        await prefs.setString("nombre", nombreCompleto);

        final placa = result["trabajador"]["placa"] as String?;
        if (placa != null) {
          await prefs.setString("placa_camion", placa);
        }

        if (mounted) {
          final rol = (rolId == 1) ? "gerente" : "conductor";
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Home(
                nombre: nombreCompleto,
                rol: rol,
                placaCamion: placa, // <-- pasamos la placa
              ),
            ),
          );
        }
      } else {
        setState(() => _errorMessage = "Credenciales incorrectas");
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Image(image: AssetImage('images/logo_deltrans.png')),
                    const SizedBox(height: 50),
                    const Text('Iniciar Sesión',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Usuario',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ingrese su usuario',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Contraseña',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ingrese su contraseña',
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Iniciar sesión',
                              style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
