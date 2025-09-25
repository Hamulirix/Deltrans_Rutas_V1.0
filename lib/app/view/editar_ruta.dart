import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/seleccionar_punto.dart';

class EditarRutaPage extends StatefulWidget {
  final String nombreRuta;                  // p.ej. "Ruta 1 - 60 puntos"
  final List<Map<String, dynamic>> puntos;  // lista original de puntos
  final List<Map<String, dynamic>> catalogoPuntos; // catálogo para “Añadir punto”

  const EditarRutaPage({
    super.key,
    required this.nombreRuta,
    required this.puntos,
    required this.catalogoPuntos,
  });

  @override
  State<EditarRutaPage> createState() => _EditarRutaPageState();
}

class _EditarRutaPageState extends State<EditarRutaPage> {
  late List<Map<String, dynamic>> _puntos;

  @override
  void initState() {
    super.initState();
    _puntos = List<Map<String, dynamic>>.from(widget.puntos);
  }

  void _eliminarPunto(int index) {
    setState(() {
      _puntos.removeAt(index);
    });
  }

  Future<void> _anadirPunto() async {
    // Navega a la pantalla de selección (con búsqueda/paginación)
    final seleccionado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarPuntoPage(
          catalogo: widget.catalogoPuntos,
          pageSize: 10,
        ),
      ),
    );

    if (seleccionado != null) {
      setState(() {
        // Lo agregamos al final para mantener el orden actual
        _puntos.add(seleccionado);
      });
    }
  }

  void _establecerRuta() {
    Navigator.pop(context, _puntos); // devolver al caller
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar ruta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // cancelar sin guardar
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado y botón añadir
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.nombreRuta,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _anadirPunto,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir punto'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista de puntos con icono eliminar
            Expanded(
              child: _puntos.isEmpty
                  ? const Center(child: Text('Sin puntos en la ruta'))
                  : ListView.separated(
                      itemCount: _puntos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        final p = _puntos[index];
                        final direccion = (p['direccion'] ?? '').toString().trim();
                        final codigo = (p['codigo'] ?? '').toString().trim();
                        final texto = direccion.isNotEmpty
                            ? '$direccion${codigo.isNotEmpty ? " ($codigo)" : ""}'
                            : 'Punto ${index + 1}';

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 28, child: Text('${index + 1}.')),
                            Expanded(
                              child: Text(
                                texto,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _eliminarPunto(index),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Botón establecer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _puntos.isNotEmpty ? _establecerRuta : null,
                child: const Text('Establecer ruta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
