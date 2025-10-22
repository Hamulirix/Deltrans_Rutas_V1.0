// forms.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// ===============================
/// Helpers comunes
/// ===============================
class LabeledSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const LabeledSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

InputDecoration _dec(String label, {String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffix,
    );

String? _req(String? v, {String msg = 'Campo obligatorio'}) =>
    (v == null || v.trim().isEmpty) ? msg : null;

final _dniFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));
final _placaFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[A-Za-z0-9\\-]'),
);

// ✅ Permite letras de todos los idiomas, incluidas ñ/Ñ y acentos
final _soloTextoFormatter = FilteringTextInputFormatter.allow(
  RegExp(r"[^\d\W_]", unicode: true),
);
final _soloTextoRegex = RegExp(r"^[^\d\W_]+(?:\s[^\d\W_]+)*$", unicode: true);

class UsuarioFormPage extends StatefulWidget {
  final int? usuarioId;
  final UsuarioUpdateDto? initial;

  const UsuarioFormPage({super.key, this.usuarioId, this.initial});

  @override
  State<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<UsuarioFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _dni = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  int? _idCamion;
  int? _idTipoTrabajador;
  bool _estado = true;

  bool _loading = false;
  List<Camion> _camiones = [];
  List<TipoTrabajador> _tipos = [];

  bool get _esEdicion => widget.usuarioId != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nombres.text = i.nombres;
      _apellidos.text = i.apellidos;
      _dni.text = i.dni;
      _username.text = i.username;
      _estado = i.estado ?? true;
      _idCamion = i.idCamion;
      _idTipoTrabajador = i.idTipoTrabajador == 0 ? null : i.idTipoTrabajador;
    }
    _cargarData();
  }

  Future<void> _cargarData() async {
    try {
      setState(() => _loading = true);

      UsuarioDetalle? detalle;
      if (widget.usuarioId != null) {
        detalle = await _api.obtenerUsuarioDetalle(widget.usuarioId!);
        _nombres.text = detalle.nombres;
        _apellidos.text = detalle.apellidos;
        _dni.text = detalle.dni;
        _username.text = detalle.username;
        _estado = detalle.estado;
        _idCamion = detalle.idCamion;
        _idTipoTrabajador = detalle.idTipoTrabajador;
      }

      final results = await Future.wait([
        _api.listarTiposTrabajador(),
        _api.listarCamionesDisponibles(includeId: detalle?.idCamion),
      ]);

      setState(() {
        _tipos = results[0] as List<TipoTrabajador>;
        _camiones = results[1] as List<Camion>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar datos del formulario: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _dni.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_esEdicion) {
      // === UPDATE ===
      final dto = UsuarioUpdateDto(
        nombres: _nombres.text.trim(),
        apellidos: _apellidos.text.trim(),
        dni: _dni.text.trim(),
        idTipoTrabajador: _idTipoTrabajador ?? 0,
        username: _username.text.trim(),
        idCamion: _idCamion,
        estado: _estado,
      );

      setState(() => _loading = true);
      try {
        final msg = await _api.actualizarUsuario(widget.usuarioId!, dto);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.of(context).maybePop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // === CREATE ===
      final dto = UsuarioCreateDto(
        nombres: _nombres.text.trim(),
        apellidos: _apellidos.text.trim(),
        dni: _dni.text.trim(),
        idTipoTrabajador: _idTipoTrabajador ?? 0,
        username: _username.text.trim(),
        password: _password.text, // requerido
        idCamion: _idCamion,
        estado: _estado,
      );

      setState(() => _loading = true);
      try {
        await _api.registrarUsuario(dto);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado con éxito')),
        );
        Navigator.of(context).maybePop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esEdicion ? 'Editar usuario' : 'Nuevo usuario';
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                // 🧍‍♂️ Nombres: solo texto
                TextFormField(
                  controller: _nombres,
                  decoration: _dec('Nombres'),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_soloTextoFormatter],
                  validator: (v) {
                    if (_req(v) != null) return 'Campo obligatorio';
                    if (!_soloTextoRegex.hasMatch(v!.trim())) {
                      return 'Solo se permiten letras y espacios';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 👨‍🦱 Apellidos: solo texto
                TextFormField(
                  controller: _apellidos,
                  decoration: _dec('Apellidos'),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_soloTextoFormatter],
                  validator: (v) {
                    if (_req(v) != null) return 'Campo obligatorio';
                    if (!_soloTextoRegex.hasMatch(v!.trim())) {
                      return 'Solo se permiten letras y espacios';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // DNI sigue igual
                TextFormField(
                  controller: _dni,
                  decoration: _dec('DNI', hint: '8 dígitos'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // ✅ Solo números
                    LengthLimitingTextInputFormatter(8), // ✅ Máximo 8 dígitos
                  ],
                  validator: (v) {
                    if (_req(v) != null) return 'Campo obligatorio';
                    final dni = v!.trim();
                    if (dni.length != 8)
                      return 'El DNI debe tener exactamente 8 dígitos';
                    if (!RegExp(r'^\d{8}$').hasMatch(dni)) {
                      return 'Solo se permiten números';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Tipo de trabajador
                DropdownButtonFormField<int>(
                  initialValue: _idTipoTrabajador,
                  decoration: _dec('Tipo de trabajador'),
                  items: _tipos
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t.id,
                          child: Text(t.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _idTipoTrabajador = v),
                  validator: (v) => v == null ? 'Selecciona un tipo' : null,
                ),
                const SizedBox(height: 12),

                // Camión (opcional)
                DropdownButtonFormField<int?>(
                  initialValue: _idCamion,
                  decoration: _dec('Camión asignado (opcional)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— Sin camión —'),
                    ),
                    ..._camiones.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.idCamion,
                        child: Text('${c.placa} (${c.marca} ${c.modelo})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _idCamion = v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _username,
                  decoration: _dec('Usuario'),
                  validator: _req,
                ),
                const SizedBox(height: 12),

                // Contraseña SOLO en creación
                if (!_esEdicion)
                  TextFormField(
                    controller: _password,
                    decoration: _dec('Contraseña'),
                    obscureText: true,
                    validator: (v) => _req(v, msg: 'Ingresa una contraseña'),
                  ),

                const SizedBox(height: 12),
                LabeledSwitch(
                  label: 'Estado',
                  value: _estado,
                  onChanged: (v) => setState(() => _estado = v),
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _loading
                        ? 'Guardando...'
                        : (_esEdicion ? 'Guardar' : 'Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================================================
/// FORM: CAMIÓN (placa, modelo, marca, capacidad_max, estado)
/// =======================================================
class CamionFormPage extends StatefulWidget {
  final Camion? initial; // si viene, modo edición
  final void Function(CamionCreateDto dto)? onCreate;
  final void Function(CamionUpdateDto dto)? onUpdate;

  const CamionFormPage({super.key, this.initial, this.onCreate, this.onUpdate});

  @override
  State<CamionFormPage> createState() => _CamionFormPageState();
}

class _CamionFormPageState extends State<CamionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _placa = TextEditingController();
  final _modelo = TextEditingController();
  final _marca = TextEditingController();
  final _capacidad = TextEditingController();

  bool _estado = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _placa.text = i.placa;
      _modelo.text = i.modelo;
      _marca.text = i.marca;
      _capacidad.text = i.capacidadMax.toString();
      _estado = i.disponible;
    }
  }

  @override
  void dispose() {
    _placa.dispose();
    _modelo.dispose();
    _marca.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final capacidad = int.tryParse(_capacidad.text.trim()) ?? 0;

    if (widget.initial == null) {
      final dto = CamionCreateDto(
        placa: _placa.text.trim().toUpperCase(),
        modelo: _modelo.text.trim(),
        marca: _marca.text.trim(),
        capacidadMax: capacidad,
        estado: _estado,
      );
      if (widget.onCreate != null) {
        widget.onCreate!(dto);
        return;
      }
      setState(() => _loading = true);
      try {
        final res = await _api.crearCamion(dto);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Creado: #${res['id_camion']} (${res['placa']})'),
            ),
          );
          Navigator.of(context).maybePop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      final dto = CamionUpdateDto(
        placa: _placa.text.trim().toUpperCase(),
        modelo: _modelo.text.trim(),
        marca: _marca.text.trim(),
        capacidadMax: capacidad,
        estado: _estado,
      );
      if (widget.onUpdate != null) {
        widget.onUpdate!(dto);
        return;
      }
      setState(() => _loading = true);
      try {
        final msg = await _api.actualizarCamion(widget.initial!.idCamion, dto);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
          Navigator.of(context).maybePop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nuevo camión' : 'Editar camión'),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                TextFormField(
                  controller: _placa,
                  decoration: _dec('Placa', hint: 'Ej. ABC-123'),
                  inputFormatters: [_placaFormatter, UpperCaseTextFormatter()],
                  validator: (v) {
                    if (_req(v) != null) return 'Campo obligatorio';
                    if (!RegExp(r'^[A-Za-z0-9\-]{5,10}$').hasMatch(v!.trim())) {
                      return 'Formato inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelo,
                  decoration: _dec('Modelo'),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _marca,
                  decoration: _dec('Marca'),
                  inputFormatters: [_soloTextoFormatter],
                  validator: (v) {
                    if (_req(v) != null) return 'Campo obligatorio';
                    if (!_soloTextoRegex.hasMatch(v!.trim())) {
                      return 'Solo se permiten letras y espacios';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _capacidad,
                  decoration: _dec('Capacidad máx. (unidades)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_dniFormatter],
                  validator: (v) {
                    if (_req(v) != null) return 'Campo obligatorio';
                    final n = int.tryParse(v!.trim()) ?? 0;
                    if (n <= 0) return 'Debe ser un entero positivo';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                LabeledSwitch(
                  label: 'Estado (disponible)',
                  value: _estado,
                  onChanged: (v) => setState(() => _estado = v),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_loading ? 'Guardando...' : 'Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// =======================================================
/// FORM: RUTA (fecha, camión, estado | sin endpoint de creación/edición en tu backend)
/// =======================================================
class RutaFormPage extends StatefulWidget {
  final void Function(DateTime fecha, int idCamion, bool estado)? onSubmit;
  final DateTime? initialFecha;
  final int? initialIdCamion;
  final bool initialEstado;

  const RutaFormPage({
    super.key,
    this.onSubmit,
    this.initialFecha,
    this.initialIdCamion,
    this.initialEstado = true,
  });

  @override
  State<RutaFormPage> createState() => _RutaFormPageState();
}

class _RutaFormPageState extends State<RutaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  DateTime? _fecha;
  int? _idCamion;
  bool _estado = true;

  final bool _loading = false;
  List<Camion> _camiones = [];

  @override
  void initState() {
    super.initState();
    _fecha = widget.initialFecha;
    _idCamion = widget.initialIdCamion;
    _estado = widget.initialEstado;
    _cargarCamiones();
  }

  Future<void> _cargarCamiones() async {
    try {
      final lista = await _api.listarCamiones();
      setState(() => _camiones = lista.where((c) => c.disponible).toList());
    } catch (_) {
      /*silencio UI*/
    }
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.onSubmit != null) {
      widget.onSubmit!(_fecha!, _idCamion!, _estado);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Este backend solo lista/da de baja rutas. Usa onSubmit para manejar creación/edición.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaText = _fecha == null
        ? 'Selecciona fecha'
        : '${_fecha!.day.toString().padLeft(2, '0')}/${_fecha!.month.toString().padLeft(2, '0')}/${_fecha!.year}';
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de ruta')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                GestureDetector(
                  onTap: _pickFecha,
                  child: InputDecorator(
                    decoration: _dec('Fecha'),
                    child: Row(
                      children: [
                        const Icon(Icons.event),
                        const SizedBox(width: 8),
                        Text(fechaText),
                        const Spacer(),
                        TextButton(
                          onPressed: _pickFecha,
                          child: const Text('Cambiar'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _idCamion,
                  decoration: _dec('Camión'),
                  items: _camiones
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.idCamion,
                          child: Text('${c.placa} (${c.marca} ${c.modelo})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _idCamion = v),
                  validator: (v) => v == null ? 'Selecciona un camión' : null,
                ),
                const SizedBox(height: 12),
                LabeledSwitch(
                  label: 'Estado (activo)',
                  value: _estado,
                  onChanged: (v) => setState(() => _estado = v),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Para “dar de baja” usa ApiService.eliminarRuta(idRuta).',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Dar de baja (info)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
