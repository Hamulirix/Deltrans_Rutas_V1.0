import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AsignarRutasPage extends StatefulWidget {
  const AsignarRutasPage({super.key});

  @override
  State<AsignarRutasPage> createState() => _AsignarRutasPageState();
}

class _AsignarRutasPageState extends State<AsignarRutasPage> {
  final _api = ApiService();

  // Datos reales
  List<Camion> _camiones = [];
  List<RutaResumen> _rutas = [];

  // Selección
  int? _camionSeleccionado; // id_camion
  int? _rutaSeleccionada; // id_ruta
  DateTime? _fechaSeleccionada = DateTime.now();

  // UI
  bool _loadingCamiones = false;
  bool _loadingRutas = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
  }

  Future<void> _cargarCamiones() async {
    setState(() => _loadingCamiones = true);
    try {
      final lista = await _api.listarCamiones();
      setState(() {
        _camiones = lista;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingCamiones = false);
    }
  }

  Future<void> _cargarRutasDeCamion(int idCamion) async {
    setState(() {
      _loadingRutas = true;
      _rutas = [];
      _rutaSeleccionada = null;
    });
    try {
      final lista = await _api.listarRutasPorCamion(idCamion);
      setState(() => _rutas = lista);
      if (lista.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este camión no tiene rutas pendientes.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingRutas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rutaSel = _rutas
        .where((r) => r.idRuta == _rutaSeleccionada)
        .cast<RutaResumen?>()
        .firstOrNull;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Programación de rutas')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Programación de rutas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              _buildSeccionCamiones(),
              const SizedBox(height: 20),

              _buildSeccionRutas(),
              const SizedBox(height: 20),

              if (rutaSel != null) _buildSeccionPuntos(rutaSel),
              if (rutaSel != null) const SizedBox(height: 20),

              _buildSelectorFecha(),
              const SizedBox(height: 30),

              _buildBotonAsignar(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= Secciones =================

  Widget _buildSeccionCamiones() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Camión',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            if (_loadingCamiones)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _camionSeleccionado,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _camiones
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c.idCamion,
                        child: Text('${c.placa} • ${c.marca} ${c.modelo}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _camionSeleccionado = value;
                  });
                  if (value != null) {
                    _cargarRutasDeCamion(value);
                  }
                },
                hint: const Text('Selecciona un camión'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionRutas() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ruta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            if (_camionSeleccionado == null)
              const Text('Elige un camión para ver sus rutas pendientes.')
            else if (_loadingRutas)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _rutaSeleccionada,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _rutas
                    .map(
                      (r) => DropdownMenuItem<int>(
                        value: r.idRuta,
                        child: Text('Ruta #${r.idRuta} • ${r.nPuntos} puntos'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _rutaSeleccionada = value),
                hint: const Text('Selecciona una ruta'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionPuntos(RutaResumen r) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puntos de la ruta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            if (r.primerPunto != null)
              _buildItemPunto('Primer punto', r.primerPunto!),
            if (r.primerPunto != null) const SizedBox(height: 10),
            if (r.ultimoPunto != null)
              _buildItemPunto('Último punto', r.ultimoPunto!),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPunto(String titulo, String valor) {
    return Row(
      children: [
        Text(
          '$titulo: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorFecha() {
    final text = _fechaSeleccionada == null
        ? ''
        : '${_fechaSeleccionada!.day.toString().padLeft(2, '0')}-'
              '${_fechaSeleccionada!.month.toString().padLeft(2, '0')}-'
              '${_fechaSeleccionada!.year}';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fecha',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(text: text),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintText: 'DD-MM-AAAA',
                    ),
                    readOnly: true,
                    onTap: _mostrarSelectorFechaSimple,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _mostrarSelectorFechaSimple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorFechaSimple() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar fecha'),
        content: SizedBox(
          width: double.maxFinite,
          child: CalendarDatePicker(
            initialDate: _fechaSeleccionada ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (DateTime value) {
              setState(() => _fechaSeleccionada = value);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBotonAsignar() {
    final puedeAsignar =
        _camionSeleccionado != null &&
        _rutaSeleccionada != null &&
        _fechaSeleccionada != null &&
        !_saving;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: puedeAsignar ? _asignarRuta : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Asignar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _asignarRuta() async {
    if (_rutaSeleccionada == null ||
        _camionSeleccionado == null ||
        _fechaSeleccionada == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      // 1) Llamar backend
      final res = await _api.actualizarFechaRuta(
        idRuta: _rutaSeleccionada!,
        fecha: _fechaSeleccionada!, // o null si quisieras limpiar
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Asignación realizada')),
      );

      // 2) Recargar rutas del camión para que desaparezcan las ya asignadas
      await _cargarRutasDeCamion(_camionSeleccionado!);

      // 3) (Opcional) Resetear selección de ruta
      setState(() {
        _rutaSeleccionada = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e
          .toString(); // si usas ApiException, será el mensaje limpio del backend
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// Pequeña extensión útil
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
