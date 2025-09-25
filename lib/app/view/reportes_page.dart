import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  // ======== Filtro ========
  int _rangeDays = 7; // 7 | 30 | 90

  // ======== Mock de datos ========
  late final List<RutaMock> _rutas = _genRutasMock(120);
  late List<RutaMock> _rutasFiltradas;

  @override
  void initState() {
    super.initState();
    _aplicarFiltro();
  }

  void _aplicarFiltro() {
    final hoy = DateTime.now();
    final hoyOnly = DateUtils.dateOnly(hoy);
    final desde = hoyOnly.subtract(Duration(days: _rangeDays - 1));
    _rutasFiltradas = _rutas.where((r) {
      final d = DateUtils.dateOnly(r.fecha);
      return !d.isBefore(desde) && !d.isAfter(hoyOnly);
    }).toList();
    setState(() {});
  }

  // ======== Agregaciones ========
  List<DailyCount> _rutasPorDia() {
    final map = <DateTime, int>{};
    for (var r in _rutasFiltradas) {
      final key = DateUtils.dateOnly(r.fecha);
      map[key] = (map[key] ?? 0) + 1;
    }
    final hoy = DateTime.now();
    final hoyOnly = DateUtils.dateOnly(hoy);
    final desde = hoyOnly.subtract(Duration(days: _rangeDays - 1));
    final res = <DailyCount>[];
    for (int i = 0; i < _rangeDays; i++) {
      final d = DateUtils.dateOnly(desde.add(Duration(days: i)));
      res.add(DailyCount(d, map[d] ?? 0));
    }
    return res;
  }

  PointsSummary _puntosVisitadosPendientes() {
    int visitados = 0;
    int pendientes = 0;
    for (var r in _rutasFiltradas) {
      visitados += r.puntosVisitados;
      pendientes += r.puntosPendientes;
    }
    return PointsSummary(visitados: visitados, pendientes: pendientes);
  }

  RouteStateSummary _estadoRutas() {
    int activas = 0, inactivas = 0;
    for (var r in _rutasFiltradas) {
      if (r.activa) {
        activas++;
      } else {
        inactivas++;
      }
    }
    return RouteStateSummary(activas: activas, inactivas: inactivas);
  }

  // ======== UI ========
  @override
  Widget build(BuildContext context) {
    final rutasDia = _rutasPorDia();
    final points = _puntosVisitadosPendientes();
    final estados = _estadoRutas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rangeDays,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 días')),
                  DropdownMenuItem(value: 30, child: Text('30 días')),
                  DropdownMenuItem(value: 90, child: Text('90 días')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _rangeDays = v;
                  _aplicarFiltro();
                },
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Rutas por día',
            subtitle: 'Cantidad de rutas registradas en el período',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= rutasDia.length) return const SizedBox();
                          final d = rutasDia[idx].date;
                          return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10));
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
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      spots: List.generate(
                        rutasDia.length,
                        (i) => FlSpot(i.toDouble(), rutasDia[i].count.toDouble()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Puntos visitados vs. pendientes',
            subtitle: 'Suma total de puntos en el período',
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
                          switch (value.toInt()) {
                            case 0: return const Text('Visitados');
                            case 1: return const Text('Pendientes');
                            default: return const SizedBox();
                          }
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: points.visitados.toDouble())]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: points.pendientes.toDouble())]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Estado de rutas',
            subtitle: 'Distribución de rutas activas/inactivas',
            child: SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: [
                    PieChartSectionData(
                      value: estados.activas.toDouble(),
                      title: 'Activas\n${estados.activas}',
                      radius: 70,
                    ),
                    PieChartSectionData(
                      value: estados.inactivas.toDouble(),
                      title: 'Inactivas\n${estados.inactivas}',
                      radius: 70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== Helpers Mock (en el mismo archivo) =====================
  List<RutaMock> _genRutasMock(int diasAtras) {
    final rand = Random(1);
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    final rutas = <RutaMock>[];
    for (int d = 0; d < diasAtras; d++) {
      final fecha = base.subtract(Duration(days: d));
      final rutasHoy = rand.nextInt(7); // 0..6 rutas por día
      for (int i = 0; i < rutasHoy; i++) {
        final totalPuntos = 40 + rand.nextInt(20); // 40..59
        final visitados = rand.nextInt(totalPuntos + 1);
        rutas.add(
          RutaMock(
            fecha: fecha,
            activa: rand.nextBool(),
            puntosVisitados: visitados,
            puntosPendientes: totalPuntos - visitados,
          ),
        );
      }
    }
    return rutas;
  }
}

// ===================== Modelos simples (en el mismo archivo) =====================
class RutaMock {
  final DateTime fecha;
  final bool activa;
  final int puntosVisitados;
  final int puntosPendientes;
  RutaMock({
    required this.fecha,
    required this.activa,
    required this.puntosVisitados,
    required this.puntosPendientes,
  });
}

class DailyCount {
  final DateTime date;
  final int count;
  DailyCount(this.date, this.count);
}

class PointsSummary {
  final int visitados;
  final int pendientes;
  PointsSummary({required this.visitados, required this.pendientes});
}

class RouteStateSummary {
  final int activas;
  final int inactivas;
  RouteStateSummary({required this.activas, required this.inactivas});
}

// ===================== UI Helper (mismo archivo) =====================
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
