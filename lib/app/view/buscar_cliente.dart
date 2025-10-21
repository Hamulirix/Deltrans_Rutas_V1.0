import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'crear_cliente.dart';

class BuscarClientePage extends StatefulWidget {
  final LatLng posicion; // por si luego quieres mostrarla

  const BuscarClientePage({super.key, required this.posicion});

  @override
  State<BuscarClientePage> createState() => _BuscarClientePageState();
}

class _BuscarClientePageState extends State<BuscarClientePage> {
  final _codigoCtrl = TextEditingController();
  Map<String, dynamic>? _cliente;
  bool _loading = false;
  String? _error;

  Future<void> _buscar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      setState(() {
        _cliente = null;
        _error = "Ingresa un código";
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _cliente = null;
    });

    try {
      final c = await ApiService().buscarClientePorCodigo(codigo);
      setState(() {
        _cliente = c; // puede ser null si 404
      });
      if (c == null) {
        setState(() {
          _error = "Cliente no encontrado";
        });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = "Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _aceptarExistente() {
    if (_cliente == null) return;
    Navigator.pop(context, {
      "id_cliente": _cliente!["id_cliente"],
      "codigo": _cliente!["codigo"],
      "nombres": _cliente!["nombres"],
      "giro": _cliente!["giro"],
    });
  }

  Future<void> _irCrearCliente() async {
    final creado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CrearClientePage(
          codigoInicial: _codigoCtrl.text.trim(),
        ),
        fullscreenDialog: true,
      ),
    );
    if (creado != null) {
      Navigator.pop(context, creado); // devolvemos directo al mapa
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar cliente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigoCtrl,
                    decoration: const InputDecoration(
                      labelText: "Ingrese código de cliente",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _buscar,
                  icon: const Icon(Icons.search),
                  label: const Text("Buscar"),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _irCrearCliente,
                child: const Text("Añadir nuevo cliente"),
              ),
            ],
            if (_cliente != null) ...[
              TextFormField(
                readOnly: true,
                initialValue: _cliente!["nombres"]?.toString() ?? "",
                decoration: const InputDecoration(
                  labelText: "Nombres",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _aceptarExistente,
                      child: const Text("Usar este cliente"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _irCrearCliente,
                      child: const Text("Añadir nuevo cliente"),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
