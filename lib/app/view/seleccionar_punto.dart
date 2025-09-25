import 'package:flutter/material.dart';

class SeleccionarPuntoPage extends StatefulWidget {
  final List<Map<String, dynamic>> catalogo; // lista completa disponible
  final int pageSize;

  const SeleccionarPuntoPage({
    super.key,
    required this.catalogo,
    this.pageSize = 10,
  });

  @override
  State<SeleccionarPuntoPage> createState() => _SeleccionarPuntoPageState();
}

class _SeleccionarPuntoPageState extends State<SeleccionarPuntoPage> {
  final _searchCtrl = TextEditingController();
  int _page = 0;

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.catalogo;
    return widget.catalogo.where((p) {
      final direccion = (p['direccion'] ?? '').toString().toLowerCase();
      final codigo    = (p['codigo'] ?? '').toString().toLowerCase();
      final cliente   = (p['cliente'] ?? '').toString().toLowerCase();
      return direccion.contains(q) || codigo.contains(q) || cliente.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _filtered.length;
    final totalPages = (total / widget.pageSize).ceil().clamp(1, 1 << 30);
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, total);
    final pageItems = _filtered.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir punto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Buscador
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por dirección, código o cliente',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _page = 0), // resetea página al filtrar
            ),
            const SizedBox(height: 12),

            // Cards de puntos
            Expanded(
              child: pageItems.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.builder(
                      itemCount: pageItems.length,
                      itemBuilder: (_, i) {
                        final p = pageItems[i];
                        final direccion = (p['direccion'] ?? '').toString().trim();
                        final codigo = (p['codigo'] ?? '').toString().trim();
                        final cliente = (p['cliente'] ?? '').toString().trim();
                        final giro = (p['giro'] ?? '').toString().trim();

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(
                              direccion.isNotEmpty ? direccion : 'Sin dirección',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (cliente.isNotEmpty) Text(cliente),
                                if (giro.isNotEmpty) Text(giro, style: const TextStyle(fontSize: 12)),
                                if (codigo.isNotEmpty)
                                  Text('Código: $codigo', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => Navigator.pop(context, p),
                              child: const Text('Elegir'),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Paginación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Página ${_page + 1} de $totalPages'),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _page > 0 ? () => setState(() => _page--) : null,
                      child: const Text('Anterior'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: (_page + 1) < totalPages ? () => setState(() => _page++) : null,
                      child: const Text('Siguiente'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
