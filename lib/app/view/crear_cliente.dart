import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Necesario para inputFormatters
import 'package:flutter_application_1/app/services/api_service.dart';

class CrearClientePage extends StatefulWidget {
  final String? codigoInicial;

  const CrearClientePage({super.key, this.codigoInicial});

  @override
  State<CrearClientePage> createState() => _CrearClientePageState();
}

class _CrearClientePageState extends State<CrearClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _giroCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.codigoInicial != null && widget.codigoInicial!.isNotEmpty) {
      _codigoCtrl.text = widget.codigoInicial!;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final res = await ApiService().crearCliente(
        codigo: _codigoCtrl.text.trim(),
        nombres: _nombresCtrl.text.trim(),
        giro: _giroCtrl.text.trim(),
      );
      // devolver info mínima requerida por el mapa
      Navigator.pop<Map<String, dynamic>>(context, {
        "id_cliente": res["id_cliente"],
        "codigo": _codigoCtrl.text.trim(),
        "nombres": _nombresCtrl.text.trim(),
        "giro": _giroCtrl.text.trim(),
      });
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = "Error: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Añadir nuevo cliente")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // 🧮 Código: solo números
                TextFormField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: "Código",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Requerido";
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                      return "Solo se permiten números";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nombresCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nombres",
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ\s]'),
                    ),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Requerido";
                    }
                    if (!RegExp(r'^[A-Za-zÁÉÍÓÚáéíóúÑñ\s]+$').hasMatch(v)) {
                      return "Solo se permiten letras";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _giroCtrl,
                  decoration: const InputDecoration(
                    labelText: "Giro",
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ\s]'),
                    ),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Requerido";
                    }
                    if (!RegExp(r'^[A-Za-zÁÉÍÓÚáéíóúÑñ\s]+$').hasMatch(v)) {
                      return "Solo se permiten letras";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Añadir cliente"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
