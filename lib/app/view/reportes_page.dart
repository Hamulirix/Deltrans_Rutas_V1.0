import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final _api = ApiService();

  // ====== Estado filtro ======
  List<Camion> _camiones = [];
  Camion? _camionSel;

  // Fechas (DatePicker)
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool _cargandoInit = true;
  bool _cargandoConsulta = false;

  // ====== Datos API ======
  List<_RutaFecha> _rutasPorFecha = [];
  List<_ParNombreValor> _rutasPorEstado = [];
  List<_ParNombreValor> _puntosPorVisita = [];

  @override
  void initState() {
    super.initState();
    _initCargar();
  }

  Future<void> _initCargar() async {
    try {
      // Fechas por defecto: últimos 7 días
      final hoy = DateTime.now();
      final hoyOnly = DateTime(hoy.year, hoy.month, hoy.day);
      final desde = hoyOnly.subtract(const Duration(days: 6));

      _fechaInicio = desde;
      _fechaFin = hoyOnly;

      // Camiones
      _camiones = await _api.listarCamiones();
      if (_camiones.isNotEmpty) _camionSel = _camiones.first;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inicializando: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoInit = false);
    }
  }

  Future<void> _consultar() async {
    if (_camionSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un camión')),
      );
      return;
    }
    if (_fechaInicio == null || _fechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona ambas fechas')),
      );
      return;
    }

    // Normaliza a rango máximo de 7 días (inclusive)
    var fi = DateTime(_fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day);
    var ff = DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day);
    if (fi.isAfter(ff)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de inicio no puede ser mayor que la fecha fin')),
      );
      return;
    }
    final diff = ff.difference(fi).inDays;
    if (diff > 6) {
      // Ajusta a los últimos 7 días: [ff-6, ff]
      final fiAdj = ff.subtract(const Duration(days: 6));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El rango máximo es 7 días. Se ajustó automáticamente.')),
      );
      setState(() {
        _fechaInicio = fiAdj;
      });
      fi = fiAdj;
    }

    setState(() => _cargandoConsulta = true);
    try {
      final json = await _api.obtenerReportes(
        idCamion: _camionSel!.idCamion,
        fechaInicio: fi,
        fechaFin: ff,
      );

      _rutasPorFecha = (json['rutas_por_fecha'] as List? ?? [])
          .map((e) => _RutaFecha.fromJson(e))
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));

      _rutasPorEstado = (json['rutas_por_estado'] as List? ?? [])
          .map((e) => _ParNombreValor(
                nombre: (e['estado'] ?? '').toString(),
                valor: (e['cantidad_rutas'] ?? 0) as int,
              ))
          .toList();

      _puntosPorVisita = (json['puntos_por_visita'] as List? ?? [])
          .map((e) => _ParNombreValor(
                nombre: (e['estado_visita'] ?? '').toString(),
                valor: (e['cantidad_puntos'] ?? 0) as int,
              ))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error consultando: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoConsulta = false);
    }
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    if (_cargandoInit) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
      
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  // Camión
                  _ComboCamion(
                    camiones: _camiones,
                    value: _camionSel,
                    onChanged: (c) => setState(() => _camionSel = c),
                  ),

                  const SizedBox(height: 12),

                  // Fecha inicio
                  _DatePickerField(
                    label: 'Fecha inicio',
                    value: _fechaInicio,
                    onChanged: (d) => setState(() => _fechaInicio = d),
                  ),

                  const SizedBox(height: 12),

                  // Fecha fin
                  _DatePickerField(
                    label: 'Fecha fin',
                    value: _fechaFin,
                    onChanged: (d) => setState(() => _fechaFin = d),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _cargandoConsulta ? null : _consultar,
                      icon: const Icon(Icons.search),
                      label: _cargandoConsulta
                          ? const Text('Consultando...')
                          : const Text('Consultar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_rutasPorFecha.isEmpty &&
              _rutasPorEstado.isEmpty &&
              _puntosPorVisita.isEmpty)
            const Center(child: Text('Sin datos (ajusta filtros y consulta).')),

          if (_rutasPorFecha.isNotEmpty)
            _SectionCard(
              title: 'Rutas por día',
              subtitle: 'Cantidad de rutas por fecha (máx. 7 días)',
              child: SizedBox(
                height: 220,
                child: _buildBarChartRutasPorDia(),
              ),
            ),

          if (_puntosPorVisita.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Puntos visitados vs. no visitados',
              subtitle: 'Suma de puntos en el período',
              child: SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= _puntosPorVisita.length) return const SizedBox();
                            return Text(_puntosPorVisita[i].nombre, style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(
                      _puntosPorVisita.length,
                      (i) => BarChartGroupData(
                        x: i,
                        barRods: [BarChartRodData(toY: _puntosPorVisita[i].valor.toDouble())],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (_rutasPorEstado.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Estado de rutas',
              subtitle: 'Activas vs. Inactivas',
              child: SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: _rutasPorEstado
                        .map(
                          (e) => PieChartSectionData(
                            value: e.valor.toDouble(),
                            title: '${e.nombre}\n${e.valor}',
                            radius: 70,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  List<_RutaFecha> _serieRutasMax7Dias() {
    if (_fechaInicio == null || _fechaFin == null || _rutasPorFecha.isEmpty) {
      return [];
    }
    // Asegura rango 0..6
    final ff = DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day);
    final fi = DateTime(_fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day);
    final days = ff.difference(fi).inDays;
    final start = days > 6 ? ff.subtract(const Duration(days: 6)) : fi;
    final end = ff;

    int countForDay(DateTime d) {
      for (final r in _rutasPorFecha) {
        if (DateUtils.isSameDay(r.fecha, d)) return r.cantidad;
      }
      return 0;
    }

    final res = <_RutaFecha>[];
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      res.add(_RutaFecha(fecha: d, cantidad: countForDay(d)));
    }
    return res;
  }

  String _ddmm(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  Widget _buildBarChartRutasPorDia() {
    final serie = _serieRutasMax7Dias();
    final n = serie.length;

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        minY: 0,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= n) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_ddmm(serie[i].fecha), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) =>
                  Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
        barGroups: List.generate(
          n,
          (i) => BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: serie[i].cantidad.toDouble())],
          ),
        ),
      ),
    );
  }
}

// ===================== Widgets filtros =====================
class _ComboCamion extends StatelessWidget {
  final List<Camion> camiones;
  final Camion? value;
  final ValueChanged<Camion?> onChanged;
  const _ComboCamion({
    required this.camiones,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Camion>(
      decoration: const InputDecoration(
        labelText: 'Camión',
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      initialValue: value,
      items: camiones
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c.placa),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Campo de fecha en Card con CalendarDatePicker (DD-MM-AAAA)
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  String _fmt(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd-$mm-${d.year}';
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Seleccionar $label'),
        content: SizedBox(
          width: double.maxFinite,
          child: CalendarDatePicker(
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (d) {
              onChanged(DateTime(d.year, d.month, d.day));
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: _fmt(value));
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'DD-MM-AAAA',
                    ),
                    readOnly: true,
                    onTap: () => _showPicker(context),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _showPicker(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Modelos de parseo para la vista =====================
class _RutaFecha {
  final DateTime fecha;
  final int cantidad;
  _RutaFecha({required this.fecha, required this.cantidad});

  factory _RutaFecha.fromJson(Map<String, dynamic> j) {
    final f = (j['fecha'] ?? '').toString(); // "YYYY-MM-DD"
    final parts = f.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    final dt = DateTime(parts[0], parts[1], parts[2]);
    return _RutaFecha(
      fecha: dt,
      cantidad: (j['cantidad_rutas'] ?? 0) as int,
    );
  }
}

class _ParNombreValor {
  final String nombre;
  final int valor;
  _ParNombreValor({required this.nombre, required this.valor});
}

// ===================== UI Helper =====================
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
