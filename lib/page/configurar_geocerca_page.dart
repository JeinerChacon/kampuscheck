import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../providers/asistencia_provider.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import 'sesion_asistencia_page.dart';

// Distingue la apertura inmediata de una sesión y la programación futura.
/// lanzar    -> abre la toma de asistencia ahora (usa la configuración guardada del curso).
/// programar -> solo guarda la configuración que se aplicará en las próximas clases.
enum ModoGeocerca { lanzar, programar }

// Recibe los datos del curso y la configuración que se ajustará antes de continuar.
class ConfigurarGeocercaPage extends StatefulWidget {
  final Map<String, dynamic> perfil;

  /// null cuando el curso aún no existe (paso de creación): se devuelve la
  /// configuración con Navigator.pop y la guarda quien creó el curso.
  final String? cursoId;
  final Map<String, dynamic> curso;
  final ModoGeocerca modo;

  const ConfigurarGeocercaPage({
    super.key,
    required this.perfil,
    required this.cursoId,
    required this.curso,
    this.modo = ModoGeocerca.lanzar,
  });

  @override
  State<ConfigurarGeocercaPage> createState() => _ConfigurarGeocercaPageState();
}

class _ConfigurarGeocercaPageState extends State<ConfigurarGeocercaPage> {
  // Conserva una copia para detectar cambios hechos en esta pantalla.
  late final Map<String, dynamic> _inicial;
  // Mantiene los valores seleccionados de la ventana, el radio y la seguridad.
  late int _minutos;
  late int _radio;
  late bool _biometria;
  late bool _estricto;
  bool _guardarPred = true; // solo modo lanzar

  // Guarda la lectura GPS, los errores de ubicación y el estado de las acciones.
  Position? _pos;
  LatLng? _punto; // punto elegido a mano en el mapa (null = usar el GPS)
  String? _errorGps;
  bool _buscando = false;
  bool _ocupado = false;

  // Indica el flujo de apertura, los valores manuales y la configuración previa.
  bool get _lanzar => widget.modo == ModoGeocerca.lanzar;
  bool get _manual => ![10, 15, 20].contains(_minutos);
  bool get _hayGuardada => widget.curso['config'] is Map;

  @override
  void initState() {
    super.initState();
    // Inicializa los controles con la configuración del curso y busca GPS al lanzar.
    _inicial = AsistenciaProvider.configDe(widget.curso);
    _minutos = _inicial['minutos'] as int;
    _radio = _inicial['radio'] as int;
    _biometria = _inicial['biometria'] as bool;
    _estricto = _inicial['estricto'] as bool;
    if (_lanzar) _ubicar();
  }

  // Reúne en un mapa los ajustes que se guardarán o devolverán al curso.
  Map<String, dynamic> get _config => {
        'minutos': _minutos,
        'radio': _radio,
        'biometria': _biometria,
        'estricto': _estricto,
      };

  // Detecta diferencias entre los ajustes actuales y los originalmente cargados.
  bool get _cambio =>
      _minutos != _inicial['minutos'] ||
      _radio != _inicial['radio'] ||
      _biometria != _inicial['biometria'] ||
      _estricto != _inicial['estricto'] ||
      !_hayGuardada;

  // Muestra un mensaje breve en la parte inferior de la pantalla.
  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // Obtiene las coordenadas del dispositivo y actualiza la pantalla con el resultado.
  Future<void> _ubicar() async {
    setState(() {
      _buscando = true;
      _errorGps = null;
    });
    try {
      final p = await AsistenciaProvider.obtenerUbicacion();
      if (!mounted) return;
      setState(() {
        _pos = p;
        _buscando = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorGps = e.mensaje;
        _buscando = false;
      });
    }
  }

  // Abre el diálogo para ingresar una duración personalizada de registro.
  Future<void> _ajustarManual() async {
    final v = await showDialog<int>(
      context: context,
      builder: (_) => _DialogMinutos(inicial: _minutos),
    );
    if (v != null && mounted) setState(() => _minutos = v);
  }

  /// Guarda la configuración como predeterminada del curso (o la devuelve si aún no existe).
  Future<void> _guardar() async {
    final id = widget.cursoId;
    // Devuelve los ajustes al formulario de creación cuando el curso aún no existe.
    if (id == null) {
      Navigator.pop(context, _config);
      return;
    }
    // Persiste los ajustes del curso y comunica el resultado al usuario.
    setState(() => _ocupado = true);
    try {
      await AsistenciaProvider.guardarConfig(id, _config);
      if (!mounted) return;
      _aviso('Configuración guardada para las próximas clases.');
      Navigator.pop(context, _config);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _aviso(e.mensaje);
    }
  }

  // Crea una sesión usando la ubicación actual y los ajustes elegidos.
  Future<void> _lanzarSesion() async {
    final id = widget.cursoId;
    if (id == null) return;
    final nav = Navigator.of(context);
    setState(() => _ocupado = true);
    try {
      final pos = _pos ?? await AsistenciaProvider.obtenerUbicacion();
      if (_guardarPred && _cambio) {
        try {
          await AsistenciaProvider.guardarConfig(id, _config);
        } on AuthException catch (_) {} // no impide lanzar la sesión
      }
      final sesionId = await AsistenciaProvider.iniciarSesion(
        docenteUid: widget.perfil['uid'] as String,
        cursoId: id,
        cursoNombre: widget.curso['nombre'] as String,
        aula: '${widget.curso['aula'] ?? ''}',
        edificio: '${widget.curso['edificio'] ?? ''}',
        lat: _punto?.latitude ?? pos.latitude,
        lng: _punto?.longitude ?? pos.longitude,
        radio: _radio,
        minutos: _minutos,
        biometria: _biometria,
        cierreEstricto: _estricto,
      );
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) => SesionAsistenciaPage(sesionId: sesionId)));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _aviso(e.mensaje);
    }
  }

  // ───────────────────────── widgets auxiliares ─────────────────────────
  // Construye un encabezado con icono, título y contenido opcional a la derecha.
  Widget _titulo(IconData icono, String texto, {Widget? derecha}) => Row(
        children: [
          Icon(icono, color: AppColors.verde, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(texto,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ?derecha,
        ],
      );

  // Presenta una etiqueta compacta para el estado o valor seleccionado.
  Widget _chip(String texto, {Color color = AppColors.verde}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: TextStyle(fontSize: 11, color: color)),
      );

  // Muestra una alternativa seleccionable con título y breve descripción.
  Widget _opcion(String titulo, String sub, bool activo, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: activo ? AppColors.verde : AppColors.campo,
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(titulo,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: activo ? Colors.black : AppColors.texto)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11,
                      color: activo ? Colors.black87 : AppColors.gris)),
            ]),
          ),
        ),
      );

  // Dibuja una opción de radio y marca visualmente la distancia activa.
  Widget _tolerancia(int metros, String sub) {
    final activo = _radio == metros;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _radio = metros),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: activo ? AppColors.verde : AppColors.campo,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text('${metros}m ($sub)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: activo ? Colors.black : AppColors.texto)),
          ),
        ),
      ),
    );
  }

  // Representa un círculo decorativo usado en la vista previa del radio.
  Widget _circulo(double tam, int alpha) => Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.verde.withAlpha(alpha),
          border: Border.all(color: AppColors.verde.withAlpha(70)),
        ),
      );

  /// Mapa real (OpenStreetMap). Por defecto usa tu GPS; toca el mapa para
  /// ubicar el punto de la geocerca en otro lugar.
  Widget _radar() {
    final pos = _pos;
    if (pos == null || !_lanzar) return _radarSimple();
    final centro = _punto ?? LatLng(pos.latitude, pos.longitude);
    return Container(
      height: 270,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: centro,
            initialZoom: 18,
            onTap: (_, p) => setState(() => _punto = p),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.kampuscheck.app',
            ),
            CircleLayer(circles: [
              CircleMarker(
                point: centro,
                radius: _radio.toDouble(),
                useRadiusInMeter: true,
                color: AppColors.verde.withAlpha(60),
                borderColor: AppColors.verde,
                borderStrokeWidth: 2,
              ),
            ]),
            MarkerLayer(markers: [
              Marker(
                point: centro,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: AppColors.rojo, size: 40),
              ),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
        Positioned(top: 10, left: 10, child: _chip('Radio: ${_radio}m (Aula)')),
        Positioned(
          top: 6,
          right: 6,
          child: _punto == null
              ? const SizedBox.shrink()
              : TextButton.icon(
                  style: TextButton.styleFrom(backgroundColor: AppColors.tarjeta),
                  onPressed: () => setState(() => _punto = null),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Usar mi GPS', style: TextStyle(fontSize: 12)),
                ),
        ),
        Positioned(
          bottom: 22,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.tarjeta.withAlpha(220), borderRadius: BorderRadius.circular(8)),
            child: Text(
              _punto == null ? 'Punto: tu ubicación (toca el mapa para moverlo)' : 'Punto elegido a mano',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ]),
    );
  }

  /// Vista simple cuando aún no hay GPS (o al programar el curso).
  Widget _radarSimple() {
    // Escala el dibujo y prepara la precisión que se mostrará si hay GPS.
    final grande = 60.0 + _radio * 7;
    final precision = _pos == null ? '--' : _pos!.accuracy.toStringAsFixed(1);
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
          color: AppColors.campo, borderRadius: BorderRadius.circular(16)),
      child: Stack(alignment: Alignment.center, children: [
        _circulo(grande, 20),
        _circulo(grande * 0.6, 40),
        Container(
          padding: const EdgeInsets.all(6),
          decoration:
              const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
          child: const Icon(Icons.location_on, size: 16, color: Colors.black),
        ),
        Positioned(top: 10, left: 10, child: _chip('Radio: ${_radio}m (Aula)')),
        Positioned(
          bottom: 10,
          right: 12,
          child: Text('PRECISIÓN ±${precision}m',
              style: const TextStyle(fontSize: 10, color: AppColors.gris)),
        ),
      ]),
    );
  }

  // Presenta una opción de seguridad con su interruptor y descripción.
  Widget _interruptor(IconData icono, String titulo, String sub, bool valor,
          ValueChanged<bool> onChanged) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icono, color: AppColors.verde),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            ]),
          ),
          Switch(
            value: valor,
            activeTrackColor: AppColors.verde,
            activeThumbColor: Colors.black,
            onChanged: onChanged,
          ),
        ]),
      );

  // ───────────────────────────── pantalla ─────────────────────────────
  @override
  // Compone los datos del curso, los controles de geocerca y las acciones disponibles.
  Widget build(BuildContext context) {
    // Deriva los textos de horario, ubicación y estado GPS desde el curso y la pantalla.
    final c = widget.curso;
    final hora = TimeOfDay.now().format(context);
    final gpsTexto = _buscando ? 'Buscando GPS…' : (_errorGps != null ? 'GPS inactivo' : 'GPS Activo');
    final gpsColor = _errorGps != null ? AppColors.rojo : AppColors.verde;
    final horario = '${c['dias'] ?? '--'} • ${c['horario'] ?? '--'}';
    final lugar = [c['aula'], c['edificio']]
        .where((x) => x != null && '$x'.trim().isNotEmpty)
        .join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Geocerca',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // ── Datos de la sesión ──
          KampusCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                PillLabel(_lanzar ? 'SESIÓN PRESENCIAL' : 'CONFIGURACIÓN PROGRAMADA',
                    conPunto: true),
                Text('Periodo ${c['semestre'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              ]),
              const SizedBox(height: 12),
              Text('${c['nombre']}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Grupo ${c['grupo']} • $lugar',
                  style: const TextStyle(fontSize: 13, color: AppColors.gris)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(_lanzar ? Icons.access_time : Icons.event_repeat,
                      color: AppColors.verde),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_lanzar ? 'HORA DETECTADA' : 'HORARIO DE CÁTEDRA',
                          style: const TextStyle(fontSize: 10, color: AppColors.gris)),
                      Text(_lanzar ? hora : horario,
                          style: TextStyle(
                              fontSize: _lanzar ? 18 : 14, fontWeight: FontWeight.bold)),
                      if (_lanzar)
                        Text('Programada: $horario',
                            style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                    ]),
                  ),
                  _chip(_lanzar
                      ? (_hayGuardada ? 'Config. guardada' : 'Apertura Inmediata')
                      : 'Se aplica a cada clase'),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Ventana de registro ──
          KampusCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titulo(Icons.timer_outlined, 'Ventana de Registro',
                  derecha: _chip('$_minutos min activo')),
              const SizedBox(height: 8),
              const Text(
                  'Determina el lapso tras la apertura en que los alumnos podrán validar su presencia con su credencial o app.',
                  style: TextStyle(fontSize: 13, color: AppColors.gris)),
              const SizedBox(height: 14),
              Row(children: [
                _opcion('10 min', 'Rápido', _minutos == 10, () => setState(() => _minutos = 10)),
                const SizedBox(width: 10),
                _opcion('15 min', 'Recomendado', _minutos == 15, () => setState(() => _minutos = 15)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _opcion('20 min', 'Holgado', _minutos == 20, () => setState(() => _minutos = 20)),
                const SizedBox(width: 10),
                _opcion(_manual ? '$_minutos min' : 'Ajustar', 'Manual', _manual, _ajustarManual),
              ]),
              const SizedBox(height: 14),
              const InfoBox(
                icono: Icons.info_outline,
                texto:
                    'Una vez transcurrido este tiempo tras el inicio, el registro se cerrará automáticamente y ningún alumno podrá marcar asistencia.',
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Geocerca ──
          KampusCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titulo(Icons.my_location, 'Geocerca & Ubicación BLE',
                  derecha: _lanzar
                      ? Text('● $gpsTexto', style: TextStyle(fontSize: 11, color: gpsColor))
                      : null),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.place_outlined, color: AppColors.verde),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PUNTO DE REFERENCIA',
                          style: TextStyle(fontSize: 10, color: AppColors.gris)),
                      Text(lugar.isEmpty ? 'Aula asignada' : lugar,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                          !_lanzar
                              ? 'La ubicación se toma desde el aula al lanzar cada sesión'
                              : _pos == null
                                  ? 'Esperando coordenadas…'
                                  : '${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (_lanzar && _errorGps != null) ...[
                InfoBox(icono: Icons.error_outline, color: AppColors.rojo, texto: _errorGps!),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _ubicar,
                  child: const Text('Reintentar ubicación', style: TextStyle(color: AppColors.verde)),
                ),
                const SizedBox(height: 12),
              ],
              _radar(),
              const SizedBox(height: 14),
              const Text('AJUSTAR TOLERANCIA DE PROXIMIDAD',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: AppColors.gris,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _tolerancia(5, 'Ultra'),
                _tolerancia(10, 'Salón'),
                _tolerancia(15, 'Amplio'),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Seguridad ──
          KampusCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titulo(Icons.shield_outlined, 'Controles de Seguridad'),
              const SizedBox(height: 14),
              _interruptor(Icons.fingerprint, 'Validación biométrica',
                  'Huella o FaceID en app del alumno', _biometria,
                  (v) => setState(() => _biometria = v)),
              _interruptor(Icons.lock_clock, 'Cierre estricto',
                  'Bloquear asistencias extemporáneas', _estricto,
                  (v) => setState(() => _estricto = v)),
              if (_lanzar && widget.cursoId != null)
                _interruptor(Icons.save_outlined, 'Guardar para próximas clases',
                    'Queda programada para este curso; puedes cambiarla cuando quieras',
                    _guardarPred, (v) => setState(() => _guardarPred = v)),
            ]),
          ),
          const SizedBox(height: 18),

          if (_lanzar)
            PrimaryButton(
              texto: 'Lanzar Registro de Asistencia Ahora ($_minutos min)',
              icono: Icons.check_circle_outline,
              cargando: _ocupado,
              onPressed: _pos == null ? null : _lanzarSesion,
            )
          else
            PrimaryButton(
              texto: 'Guardar Configuración',
              icono: Icons.save_outlined,
              cargando: _ocupado,
              onPressed: _guardar,
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: AppColors.tarjeta, borderRadius: BorderRadius.circular(30)),
              child: const Center(
                child: Text('Cancelar y Regresar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}

/// Diálogo de duración manual (el controller vive dentro del diálogo para evitar
/// errores de "controller usado después de dispose").
class _DialogMinutos extends StatefulWidget {
  // Duración inicial que se muestra en el campo del diálogo.
  final int inicial;
  const _DialogMinutos({required this.inicial});

  @override
  State<_DialogMinutos> createState() => _DialogMinutosState();
}

class _DialogMinutosState extends State<_DialogMinutos> {
  // Controla el valor editable mientras el diálogo permanece abierto.
  late final TextEditingController _ctrl =
      TextEditingController(text: '${widget.inicial}');
  String? _error;

  @override
  void dispose() {
    // Libera el campo de texto al cerrar el diálogo.
    _ctrl.dispose();
    super.dispose();
  }

  // Devuelve la duración ingresada y cierra el diálogo.
  void _aceptar() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v < 1 || v > 180) {
      setState(() => _error = 'Ingresa un valor entre 1 y 180.');
      return;
    }
    Navigator.pop(context, v);
  }

  // Construye el formulario modal para seleccionar una duración manual.
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Duración manual'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _aceptar(),
          decoration: InputDecoration(labelText: 'Minutos (1 a 180)', errorText: _error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: _aceptar, child: const Text('Aceptar')),
        ],
      );
}