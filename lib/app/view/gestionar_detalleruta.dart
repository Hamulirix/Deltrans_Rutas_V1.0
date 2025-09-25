import 'package:flutter/material.dart';

class RutaDetallePage extends StatefulWidget {
  final int idRuta;
  final DateTime fecha;
  final String placa;
  final bool estado;
  final List<Map<String, dynamic>> puntos;

  const RutaDetallePage({
    super.key,
    required this.idRuta,
    required this.fecha,
    required this.placa,
    required this.estado,
    required this.puntos,
  });

  @override
  State<RutaDetallePage> createState() => _RutaDetallePageState();
}

class _RutaDetallePageState extends State<RutaDetallePage> {
  // --- Estado de UI ---
  String _search = '';
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtCoord(double v) => v.toStringAsFixed(6);



  @override
  Widget build(BuildContext context) {
    // --- Filtrado ---
    final q = _search.toLowerCase().trim();
    final filtrados = widget.puntos.where((p) {
      final dir = (p['direccion'] as String).toLowerCase();
      final lat = (p['latitud'] as num).toString();
      final lng = (p['longitud'] as num).toString();
      final orden = (p['orden'] as int).toString();
      return dir.contains(q) || lat.contains(q) || lng.contains(q) || orden.contains(q);
    }).toList();

    // --- Paginación ---
    final totalPages = (filtrados.isEmpty)
        ? 1
        : (filtrados.length / _itemsPerPage).ceil();
    final start = (_currentPage * _itemsPerPage).clamp(0, filtrados.length);
    final end = (start + _itemsPerPage).clamp(0, filtrados.length);
    final pageItems = filtrados.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ruta #${widget.idRuta} - ${widget.placa}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Fecha: ${_fmtFecha(widget.fecha)} • Estado: ${widget.estado ? 'Activa' : 'Inactiva'} • Puntos: ${widget.puntos.length}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔎 Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por dirección, coordenadas o # de orden...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        onPressed: () => setState(() {
                          _search = '';
                          _currentPage = 0;
                        }),
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() {
                _search = v;
                _currentPage = 0;
              }),
            ),
          ),

          // 📋 Lista paginada
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                final p = pageItems[index];
                final orden = p['orden'] as int;
                final direccion = p['direccion'] as String;
                final lat = (p['latitud'] as num).toDouble();
                final lng = (p['longitud'] as num).toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('$orden')),
                    title: Text(
                      direccion,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Lat: ${_fmtCoord(lat)}  •  Lng: ${_fmtCoord(lng)}'),
                    // ⋮ Menú de tres puntos con "Ver en mapa"
               
                  ),
                );
              },
            ),
          ),

          // ⬅️➡️ Controles de paginación
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  Text(
                    'Página ${_currentPage + 1} de $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: 'Siguiente',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: (_currentPage < totalPages - 1)
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
