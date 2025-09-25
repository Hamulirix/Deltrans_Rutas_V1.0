import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/editar_ruta.dart';
import 'package:flutter_application_1/app/services/api_service.dart';
import 'package:flutter_application_1/app/view/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app/view/home.dart';

class ResultadoRutasPage extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const ResultadoRutasPage({super.key, required this.apiData});

  @override
  State<ResultadoRutasPage> createState() => _ResultadoRutasPageState();
}

class _ResultadoRutasPageState extends State<ResultadoRutasPage> {
  late final List resultados;
  late Map<String, dynamic> placaData;
  late List rutas;
  int selectedRutaIndex = 0;

  int _page = 0;
  static const int _pageSize = 10;

  void _resetPage() => setState(() => _page = 0);

  @override
  void initState() {
    super.initState();
    resultados = (widget.apiData['resultados'] as List?) ?? [];
    if (resultados.isEmpty) {
      placaData = {"placa": "-", "resumen": {}, "rutas": []};
      rutas = [];
    } else {
      placaData = resultados.first as Map<String, dynamic>;
      rutas = (placaData['rutas'] as List?) ?? [];
    }
  }

  String _formatKm(num? km) {
    if (km == null) return '-';
    return '${km.toStringAsFixed(0)} KM';
  }

  String _formatTiempo(num? minutos) {
    if (minutos == null) return '-';
    final total = minutos.toDouble();
    final h = (total ~/ 60);
    final m = (total % 60).round();
    if (h <= 0) return '$m min';
    if (m == 0) return '$h horas';
    return '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    final resumen = (placaData['resumen'] as Map?) ?? {};
    final distanciaKm = resumen['distancia_opt_km'] as num?;
    final tiempoMin = resumen['tiempo_opt_min'] as num?;

    final cantidadRutas = rutas.length;
    final ruta = cantidadRutas > 0
        ? rutas[selectedRutaIndex] as Map<String, dynamic>
        : <String, dynamic>{};

    final allPuntos = (ruta['puntos'] as List?) ?? const [];
    final totalPuntos = allPuntos.length;

    final totalPages = (totalPuntos / _pageSize).ceil().clamp(1, 1 << 30);
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, totalPuntos);
    final pagePuntos = allPuntos.sublist(start, end);

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado de optimización')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$cantidadRutas ruta(s) generada(s)\ncorrectamente',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),

              const Text('Ruta', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedRutaIndex,
                    isExpanded: true,
                    items: List.generate(cantidadRutas, (i) {
                      final nombre =
                          (rutas[i] as Map)['nombre'] ?? 'Ruta ${i + 1}';
                      return DropdownMenuItem(value: i, child: Text(nombre));
                    }),
                    onChanged: (i) {
                      if (i == null) return;
                      setState(() {
                        selectedRutaIndex = i;
                        _page = 0;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      title: 'Distancia total estimada:',
                      value: _formatKm(distanciaKm),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatTile(
                      title: 'Tiempo total estimado:',
                      value: _formatTiempo(tiempoMin),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (totalPuntos > 0) ...[
                _PuntosListPaged(puntos: pagePuntos, offset: start),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Página ${_page + 1} de $totalPages'),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _page > 0
                              ? () => setState(() => _page--)
                              : null,
                          child: const Text('Anterior'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: (_page + 1) < totalPages
                              ? () => setState(() => _page++)
                              : null,
                          child: const Text('Siguiente'),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ruta =
                            rutas[selectedRutaIndex] as Map<String, dynamic>;
                        final puntos = List<Map<String, dynamic>>.from(
                          (ruta['puntos'] as List?) ?? [],
                        );

                        // TODO: reemplaza con catálogo real si lo tienes
                        final catalogo = <Map<String, dynamic>>[
                          {
                            "direccion": "Av. Siempre Viva 123",
                            "codigo": "C0001",
                            "cliente": "Panadería X",
                            "giro": "PANADERIA",
                          },
                        ];

                        final updated =
                            await Navigator.push<List<Map<String, dynamic>>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditarRutaPage(
                                  nombreRuta:
                                      (ruta['nombre'] ??
                                              'Ruta ${selectedRutaIndex + 1}')
                                          as String,
                                  puntos: puntos,
                                  catalogoPuntos: catalogo,
                                ),
                              ),
                            );

                        if (updated != null) {
                          setState(() {
                            ruta['puntos'] = updated;
                            ruta['total_puntos'] = updated.length;
                            final baseName =
                                (ruta['nombre'] as String?) ??
                                'Ruta ${selectedRutaIndex + 1}';
                            ruta['nombre'] =
                                '${baseName.split(' - ').first} - ${updated.length} puntos';
                            _page = 0;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Editar ruta'),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // ...
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final payload = {"resultados": resultados};
                          final api = ApiService();
                          final resp = await api.guardarRutas(payload);

                          if (!mounted) return;

                          // ✅ Mensaje de éxito
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Rutas guardadas correctamente ✅"),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );

                          // ✅ Leer nombre y rol desde SharedPreferences
                          final prefs = await SharedPreferences.getInstance();

                          // nombre completo: ojalá lo guardaste como "nombre"
                          // si no, reconstruye con "nombres" + "apellidos" si existen
                          String nombre =
                              prefs.getString("nombre") ??
                              "${prefs.getString('nombres') ?? ''} ${prefs.getString('apellidos') ?? ''}"
                                  .trim();
                          if (nombre.isEmpty) {
                            nombre = "Usuario"; // fallback amigable
                          }

                          final rolId =
                              prefs.getInt("id_tipo_trabajador") ??
                              2; // 1=gerente, otro=conductor
                          final rol = rolId == 1 ? "gerente" : "conductor";

                          // Espera breve para que se vea el SnackBar
                          await Future.delayed(const Duration(seconds: 2));

                          // ✅ Ir a Home con nombre y rol
                          Navigator.pushAndRemoveUntil(
                            // ignore: use_build_context_synchronously
                            context,
                            MaterialPageRoute(
                              builder: (_) => Home(nombre: nombre, rol: rol),
                            ),
                            (route) => false,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al guardar: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  const _StatTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PuntosListPaged extends StatelessWidget {
  final List puntos;
  final int offset;

  const _PuntosListPaged({required this.puntos, required this.offset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide = constraints.maxWidth > 520;
        final colCount = isWide ? 2 : 1;
        final half = (puntos.length / colCount).ceil();

        List<Widget> col(int start, int end) =>
            List.generate(end - start, (idx) {
              final localIndex = start + idx;
              final number = offset + localIndex + 1;
              final p = puntos[localIndex] as Map<String, dynamic>;
              final direccion = (p['direccion'] ?? '').toString().trim();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 36, child: Text('$number.')),
                    Expanded(
                      child: Text(
                        direccion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            });

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: col(0, half))),
            if (colCount == 2) const SizedBox(width: 24),
            if (colCount == 2)
              Expanded(child: Column(children: col(half, puntos.length))),
          ],
        );
      },
    );
  }
}
