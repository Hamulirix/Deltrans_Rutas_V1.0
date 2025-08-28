import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/view/login.dart';
import 'app/view/home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

Future<Widget> _determineStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("jwt_token");
  final rol = prefs.getInt("id_tipo_trabajador"); // 1 = gerente, 2 = conductor
  final nombre = prefs.getString("nombre");
  final apellidos = prefs.getString("apellidos");

  if (token != null && rol != null && nombre != null && apellidos != null) {
    return Home(
      nombre: "$nombre $apellidos",
      rol: rol == 1 ? "gerente" : "conductor",
    );
  }
  return const LoginPage();
}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deltrans',
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _determineStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Error cargando la app")),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }
}
