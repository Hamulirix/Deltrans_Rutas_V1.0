import 'package:flutter/material.dart';

class AsignarRutasPage extends StatefulWidget {
  const AsignarRutasPage({super.key});

  @override
  State<AsignarRutasPage> createState() => _AsignarRutasPageState();
}

class _AsignarRutasPageState extends State<AsignarRutasPage> {
  // Listas de datos
  final List<Map<String, dynamic>> _rutas = [
    {
      'id': '1',
      'nombre': 'Ruta 1',
      'puntos': 25,
      'primerPunto': 'Almacén Central',
      'ultimoPunto': 'Centro Comercial',
    },
    {
      'id': '2',
      'nombre': 'Ruta 25',
      'puntos': 30,
      'primerPunto': 'Planta de Producción',
      'ultimoPunto': 'Zona Industrial',
    },
    {
      'id': '3',
      'nombre': 'Ruta 3',
      'puntos': 20,
      'primerPunto': 'Depósito Norte',
      'ultimoPunto': 'Distrito Comercial',
    }
  ];

  final List<Map<String, dynamic>> _camiones = [
    {
      'id': '1',
      'placa': 'Placa 1',
      'puntosMin': 25,
      'puntosMax': 30,
    },
    {
      'id': '2',
      'placa': 'Placa 2',
      'puntosMin': 15,
      'puntosMax': 25,
    },
    {
      'id': '3',
      'placa': 'Placa 3',
      'puntosMin': 30,
      'puntosMax': 40,
    }
  ];

  // Variables para selección
  String? _rutaSeleccionada;
  String? _camionSeleccionado;
  DateTime? _fechaSeleccionada;

  // Variables para puntos de la ruta seleccionada
  String? _primerPunto;
  String? _ultimoPunto;

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programación de rutas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Programación de rutas',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            // Sección de rutas
            _buildSeccionRutas(),
            const SizedBox(height: 20),

            if (_rutaSeleccionada != null) _buildSeccionPuntos(),
            if (_rutaSeleccionada != null) const SizedBox(height: 20),

            // Sección de camiones
            _buildSeccionCamiones(),
            const SizedBox(height: 20),

            // Selector de fecha
            _buildSelectorFecha(),
            const SizedBox(height: 30),

            // Botón de asignar
            _buildBotonAsignar(),
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
            DropdownButtonFormField<String>(
              value: _rutaSeleccionada,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _rutas.map((ruta) {
                return DropdownMenuItem<String>(
                  value: ruta['id'],
                  child: Text('${ruta['nombre']} - ${ruta['puntos']} puntos'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _rutaSeleccionada = value;
                  final ruta = _rutas.firstWhere((r) => r['id'] == value);
                  _primerPunto = ruta['primerPunto'];
                  _ultimoPunto = ruta['ultimoPunto'];
                });
              },
              hint: const Text('Selecciona una ruta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionPuntos() {
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
            if (_primerPunto != null) ...[
              _buildItemPunto('Primer punto', _primerPunto!),
              const SizedBox(height: 10),
            ],
            if (_ultimoPunto != null)
              _buildItemPunto('Último punto', _ultimoPunto!),
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
            DropdownButtonFormField<String>(
              value: _camionSeleccionado,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _camiones.map((camion) {
                return DropdownMenuItem<String>(
                  value: camion['id'],
                  child: Text(
                      '${camion['placa']} - ${camion['puntosMin']} a ${camion['puntosMax']} puntos'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _camionSeleccionado = value;
                });
              },
              hint: const Text('Selecciona un camión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorFecha() {
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
                    controller: TextEditingController(
                      text: _fechaSeleccionada != null
                          ? '${_fechaSeleccionada!.day.toString().padLeft(2, '0')}-${_fechaSeleccionada!.month.toString().padLeft(2, '0')}-${_fechaSeleccionada!.year}'
                          : '',
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      hintText: 'DD-MM-AAAA',
                    ),
                    readOnly: true,
                    onTap: _mostrarSelectorFechaSimple,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary),
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
              setState(() {
                _fechaSeleccionada = value;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBotonAsignar() {
    final bool puedeAsignar = _rutaSeleccionada != null &&
        _camionSeleccionado != null &&
        _fechaSeleccionada != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: puedeAsignar ? _asignarRuta : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Asignar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _asignarRuta() {
    final ruta = _rutas.firstWhere((r) => r['id'] == _rutaSeleccionada);
    final camion = _camiones.firstWhere((c) => c['id'] == _camionSeleccionado);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Ruta ${ruta['nombre']} asignada a ${camion['placa']} para el ${_fechaSeleccionada!.day}-${_fechaSeleccionada!.month}-${_fechaSeleccionada!.year}'),
      ),
    );
  }
}
