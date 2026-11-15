import 'package:flutter/material.dart';
import '../providers/asistencia_provider.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/archivos.dart';
import '../src/horario.dart';
import 'configurar_geocerca_page.dart';

/// Registro de una nueva asignatura (paso 1 de 2): datos, horario/aula y padrón.
/// El paso 2 es la geocerca: se configura desde la tarjeta del aula y queda
/// guardada en el curso para todas sus clases.
class NuevoCursoPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const NuevoCursoPage({super.key, required this.perfil});

  @override
  State<NuevoCursoPage> createState() => _NuevoCursoPageState();
}

class _NuevoCursoPageState extends State<NuevoCursoPage> {
  // Opciones fijas de días, tipografía y color de los campos del formulario.
  static const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _mono = 'monospace';
  static const _fondoCampo = Color(0xFF080D19);

  // Controladores de los datos del curso y del padrón de estudiantes.
  final _nombre = TextEditingController();
  final _codigo = TextEditingController();
  final _grupo = TextEditingController();
  final _aula = TextEditingController();
  final _edificio = TextEditingController();
  final _campus = TextEditingController();
  final _padron = TextEditingController();
  final _sesiones = TextEditingController(); // total de sesiones del semestre

  // Selección de días, horario, geocerca y estado de carga del formulario.
  final Set<String> _dias = {};
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 10, minute: 0);
  Map<String, dynamic> _config = AsistenciaProvider.configNormalizada(null);
  bool _guardando = false;
  bool _pegar = false;

  // Guarda el archivo importado y los resultados de su validación.
  ArchivoTexto? _archivo;
  List<Map<String, String>> _validos = [];
  List<String> _errores = [];

  // Devuelve el identificador del docente que crea el curso.
  String get _uid => widget.perfil['uid'] as String;

  @override
  void dispose() {
    // Libera todos los controladores de texto asociados al formulario.
    for (final c in [_nombre, _codigo, _grupo, _aula, _edificio, _campus, _padron, _sesiones]) {
      c.dispose();
    }
    super.dispose();
  }

  // Convierte una hora local al formato de 24 horas usado por el curso.
  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  // Convierte la hora del día en minutos para comparar inicio y fin.
  int _min(TimeOfDay t) => t.hour * 60 + t.minute;
  // Informa validaciones o resultados mediante un mensaje emergente.
  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ───────────── padrón: "matrícula; nombre; correo" por línea ─────────────
  // Analiza filas pegadas o importadas y separa registros válidos de errores.
  void _procesarPadron(String texto) {
    final validos = <Map<String, String>>[];
    final errores = <String>[];
    final vistos = <String>{};
    final lineas = texto
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !RegExp(r'^[;,\s]+$').hasMatch(l))
        .toList();
    for (var i = 0; i < lineas.length; i++) {
      final partes = lineas[i]
          .split(RegExp(r'[;\t,]'))
          .map((p) => p.trim().replaceAll('"', ''))
          .toList();
      final p0 = partes.first.toLowerCase();
      // Omite una primera fila que parezca contener encabezados de columna.
      if (i == 0 &&
          (p0.contains('matr') || p0.contains('carnet') || p0 == 'id' || p0.contains('cód') || p0.contains('cod'))) {
        continue; // encabezado
      }
      final m = partes.first;
      final n = partes.length > 1 ? partes[1] : '';
      final c = partes.length > 2 ? partes[2] : '';
      if (m.isEmpty || n.isEmpty) {
        errores.add('Línea ${i + 1}: falta matrícula o nombre.');
      } else if (c.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(c)) {
        errores.add('Línea ${i + 1}: correo inválido ($c).');
      } else if (!vistos.add(m)) {
        errores.add('Línea ${i + 1}: matrícula repetida ($m).');
      } else {
        validos.add({'matricula': m, 'nombre': n, 'correo': c});
      }
    }
    setState(() {
      _validos = validos;
      _errores = errores;
    });
  }

  // Permite elegir un archivo de texto y valida las filas de su padrón.
  Future<void> _examinar() async {
    try {
      final a = await elegirArchivoTexto();
      if (a == null) return;
      _padron.text = a.texto;
      _archivo = a;
      _procesarPadron(a.texto);
      if (_validos.isEmpty && _errores.isEmpty) {
        _aviso('El archivo no contiene alumnos. Usa la plantilla oficial.');
      }
    } catch (e) {
      _aviso('No se pudo leer el archivo. Guárdalo como .csv e inténtalo de nuevo.');
    }
  }

  // Limpia el contenido importado y los resultados de su validación.
  void _quitarArchivo() {
    _padron.clear();
    setState(() {
      _archivo = null;
      _validos = [];
      _errores = [];
    });
  }

  // Genera un archivo CSV de ejemplo para completar el padrón.
  Future<void> _plantilla() async {
    const csv = 'matricula;nombre;correo\r\n'
        '20241092;Sofía Ramírez;s.ramirez@kampus.edu\r\n'
        '20241105;Carlos Mendoza;c.mendoza@kampus.edu\r\n'
        '20241142;Valentina Torres;v.torres@kampus.edu\r\n';
    try {
      final ok = await guardarArchivoTexto('plantilla_padron_kampuscheck.csv', csv);
      if (ok) _aviso('Plantilla guardada.');
    } catch (_) {
      _aviso('No se pudo guardar la plantilla.');
    }
  }

  // Abre el selector de hora para modificar el inicio o fin de la clase.
  Future<void> _hora(bool inicio) async {
    final t = await showTimePicker(context: context, initialTime: inicio ? _inicio : _fin);
    if (t == null) return;
    setState(() => inicio ? _inicio = t : _fin = t);
  }

  // Abre los ajustes de geocerca y recupera la configuración elegida.
  Future<void> _configurarGeocerca() async {
    final r = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigurarGeocercaPage(
          perfil: widget.perfil,
          cursoId: null,
          modo: ModoGeocerca.programar,
          curso: {
            'nombre': _nombre.text.trim().isEmpty ? 'Nueva asignatura' : _nombre.text.trim(),
            'grupo': _grupo.text.trim(),
            'aula': _aula.text.trim(),
            'edificio': _edificio.text.trim(),
            'semestre': semestreActual(),
            'dias': _diasSemana.where(_dias.contains).join('/'),
            'horario': '${_hhmm(_inicio)} - ${_hhmm(_fin)}',
            'config': _config,
          },
        ),
      ),
    );
    if (r != null && mounted) setState(() => _config = r);
  }

  // Valida los datos requeridos y crea el curso como publicado o borrador.
  Future<void> _guardar({required bool borrador}) async {
    // El nombre se requiere incluso cuando solo se guarda un borrador.
    if (_nombre.text.trim().isEmpty) return _aviso('Escribe el nombre de la asignatura.');
    // Los demás campos se validan al publicar el curso completo.
    if (!borrador) {
      if (_codigo.text.trim().isEmpty) return _aviso('Escribe el código de la asignatura.');
      if (_grupo.text.trim().isEmpty) return _aviso('Escribe el grupo / sección.');
      if (_dias.isEmpty) return _aviso('Selecciona al menos un día de cátedra.');
      if (_min(_fin) <= _min(_inicio)) return _aviso('La hora de salida debe ser posterior a la de inicio.');
      if (_aula.text.trim().isEmpty) return _aviso('Escribe el aula asignada.');
      final totalSes = int.tryParse(_sesiones.text.trim()) ?? 0;
      if (totalSes < 1 || totalSes > 200) return _aviso('Indica el total de sesiones del semestre (entre 1 y 200).');
      if (_validos.isEmpty) return _aviso('Carga el padrón de estudiantes.');
      if (_errores.isNotEmpty) return _aviso('Corrige las ${_errores.length} inconsistencias del padrón.');
    }
    setState(() => _guardando = true);
    try {
      // Sin cruces de horario: ni para el docente ni para los estudiantes del padrón.
      if (!borrador) {
        final choque = await AsistenciaProvider.conflictoHorario(
          docenteUid: _uid,
          dias: _diasSemana.where(_dias.contains).toList(),
          horaInicio: _hhmm(_inicio),
          horaFin: _hhmm(_fin),
          semestre: semestreActual(),
          matriculas: _validos.map((e) => e['matricula']!).toList(),
        );
        if (choque != null) throw AuthException(choque);
      }
      await AsistenciaProvider.crearCurso(
        docenteUid: _uid,
        docenteNombre: '${widget.perfil['nombre'] ?? ''}',
        nombre: _nombre.text,
        codigo: _codigo.text,
        grupo: _grupo.text,
        semestre: semestreActual(),
        aula: _aula.text,
        edificio: _edificio.text,
        campus: _campus.text,
        dias: _diasSemana.where(_dias.contains).toList(),
        horaInicio: _hhmm(_inicio),
        horaFin: _hhmm(_fin),
        config: _config,
        estudiantes: _validos,
        sesionesPlanificadas: int.tryParse(_sesiones.text.trim()) ?? 0,
        borrador: borrador,
      );
      if (!mounted) return;
      Navigator.pop(context, borrador ? 'borrador' : 'creado');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso(e.mensaje);
    }
  }

  // ───────────────────────── UI ─────────────────────────
  // Dibuja una etiqueta breve sobre un campo del formulario.
  Widget _etiqueta(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontFamily: _mono, fontSize: 12, color: AppColors.gris, fontWeight: FontWeight.w600)),
      );

  // Construye un campo de texto con icono, etiqueta y capitalización configurables.
  Widget _campo(String etiqueta, IconData icono, TextEditingController c,
      {String? hint, TextCapitalization cap = TextCapitalization.none}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _etiqueta(etiqueta),
      TextField(
        controller: c,
        textCapitalization: cap,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.gris, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icono, size: 18, color: AppColors.gris),
          filled: true,
          fillColor: _fondoCampo,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }

  // Agrupa contenido del formulario dentro de una tarjeta de sección.
  Widget _seccion({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borde),
        ),
        child: child,
      );

  // Presenta el encabezado de una sección y un distintivo opcional.
  Widget _titulo(IconData i, String t, {String? chip}) => Row(children: [
        Icon(i, color: AppColors.verde, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.verde.withAlpha(30), borderRadius: BorderRadius.circular(20)),
            child: Text(chip, style: const TextStyle(fontSize: 11, color: AppColors.verde, fontFamily: _mono)),
          ),
      ]);

  // Muestra un día seleccionable del horario semanal.
  Widget _diaChip(String d) {
    final activo = _dias.contains(d);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activo ? _dias.remove(d) : _dias.add(d)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: activo ? AppColors.verde : AppColors.campo, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: activo ? Colors.black : AppColors.texto))),
        ),
      ),
    );
  }

  // Muestra una hora seleccionable para el comienzo o cierre de la clase.
  Widget _horaCampo(String etiqueta, TimeOfDay t, bool inicio) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _etiqueta(etiqueta),
          GestureDetector(
            onTap: () => _hora(inicio),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _fondoCampo, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(inicio ? Icons.alarm : Icons.alarm_on, size: 18, color: AppColors.gris),
                const SizedBox(width: 8),
                Text('${_hhmm(t)} hrs', style: const TextStyle(fontFamily: _mono, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      );

  // Presenta los campos y datos de ubicación del aula asignada.
  Widget _tarjetaAula() {
    final aula = _aula.text.trim().isEmpty ? 'Aula' : _aula.text.trim();
    final edif = _edificio.text.trim();
    final campus = _campus.text.trim();
    return GestureDetector(
      onTap: _configurarGeocerca,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.meeting_room_outlined, color: AppColors.verde, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(edif.isEmpty ? aula : '$aula • $edif', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                if (campus.isNotEmpty) Text(campus, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gris),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.verde.withAlpha(25), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.podcasts, size: 14, color: AppColors.verde),
              const SizedBox(width: 6),
              Text('Geocerca Activa: ${_config['radio']}m BLE & GPS • ${_config['minutos']} min',
                  style: const TextStyle(fontSize: 11, color: AppColors.verde, fontFamily: _mono)),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('Toca para configurar la ventana, el radio y la seguridad de este curso.',
              style: TextStyle(fontSize: 11, color: AppColors.gris)),
        ]),
      ),
    );
  }

  // Expone las opciones para cargar un padrón o descargar su plantilla.
  Widget _zonaCarga() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _fondoCampo, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borde)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.verde.withAlpha(25)),
          child: const Icon(Icons.description, color: AppColors.verde, size: 26),
        ),
        const SizedBox(height: 10),
        const Text('Padrón (.csv)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('Selecciona la lista de tu facultad', style: TextStyle(fontSize: 12, color: AppColors.gris)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _examinar,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFF2A3347), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('Examinar Archivo', style: TextStyle(fontFamily: _mono, fontWeight: FontWeight.bold))),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _plantilla,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.download, size: 14, color: AppColors.verde),
            SizedBox(width: 6),
            Text('Descargar plantilla CSV oficial', style: TextStyle(fontSize: 12, color: AppColors.verde)),
          ]),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() => _pegar = !_pegar),
          child: Text(_pegar ? 'Ocultar lista pegada' : 'o pegar la lista manualmente', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        ),
        if (_pegar)
          TextField(
            controller: _padron,
            maxLines: 5,
            onChanged: _procesarPadron,
            style: const TextStyle(fontSize: 12, fontFamily: _mono),
            decoration: InputDecoration(
              hintText: '20241092; Sofía Ramírez; s.ramirez@kampus.edu',
              filled: true,
              fillColor: AppColors.campo,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
      ]),
    );
  }

  // Resume los estudiantes aceptados y las inconsistencias detectadas.
  Widget _resultadoPadron() {
    if (_validos.isEmpty && _errores.isEmpty) return const SizedBox.shrink();
    final a = _archivo;
    final kb = a == null ? null : (a.bytes / 1024).ceil().clamp(1, 1 << 30);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.task_alt, color: AppColors.verde),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a?.nombre ?? 'Lista pegada manualmente', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: _mono, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${kb == null ? '' : '$kb KB • '}${_validos.length + _errores.length} alumnos detectados',
                  style: const TextStyle(fontFamily: _mono, fontSize: 11, color: AppColors.gris)),
            ]),
          ),
          IconButton(onPressed: _quitarArchivo, icon: const Icon(Icons.close, color: AppColors.gris)),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (_errores.isEmpty ? AppColors.verde : AppColors.rojo).withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(_errores.isEmpty ? Icons.verified_outlined : Icons.warning_amber, size: 16, color: _errores.isEmpty ? AppColors.verde : AppColors.rojo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errores.isEmpty ? '${_validos.length} registros validados sin inconsistencias' : '${_validos.length} válidos • ${_errores.length} con inconsistencias',
                style: TextStyle(fontFamily: _mono, fontSize: 12, fontWeight: FontWeight.bold, color: _errores.isEmpty ? AppColors.verde : AppColors.rojo),
              ),
            ),
          ]),
        ),
        for (final e in _errores.take(4))
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(e, style: const TextStyle(fontSize: 12, color: AppColors.rojo))),
        if (_errores.length > 4)
          Text('… y ${_errores.length - 4} más', style: const TextStyle(fontSize: 12, color: AppColors.rojo)),
        const SizedBox(height: 8),
        for (final al in _validos.take(3))
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.campo,
                child: Text(al['nombre']!.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${al['matricula']} • ${al['nombre']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(al['correo']!.isEmpty ? 'sin correo' : al['correo']!, style: const TextStyle(fontFamily: _mono, fontSize: 11, color: AppColors.gris)),
                ]),
              ),
              const Icon(Icons.check_circle_outline, color: AppColors.verde, size: 20),
            ]),
          ),
        if (_validos.length > 3)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _fondoCampo, borderRadius: BorderRadius.circular(20)),
              child: Text('+ ${_validos.length - 3} alumnos listos para sincronizar', style: const TextStyle(fontFamily: _mono, fontSize: 11)),
            ),
          ),
      ]),
    );
  }

  @override
  // Compone el formulario por etapas y muestra el progreso de creación del curso.
  Widget build(BuildContext context) {
    final llenos = [
      _nombre.text.trim().isNotEmpty,
      _codigo.text.trim().isNotEmpty && _grupo.text.trim().isNotEmpty,
      _dias.isNotEmpty && _aula.text.trim().isNotEmpty,
      _validos.isNotEmpty && _errores.isEmpty,
    ].where((x) => x).length;
    final progreso = llenos / 4 * 0.5; // paso 1 de 2 llega hasta 50 %

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Text('Nuevo Curso', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            SizedBox(width: 6),
            Icon(Icons.verified_user_outlined, size: 15, color: AppColors.verde),
          ]),
          Text('DOCENTE', style: TextStyle(fontSize: 10, color: AppColors.verde, fontFamily: _mono, letterSpacing: 1)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline, size: 18, color: Colors.black),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _seccion(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(20)),
                  child: const Text('● CONTROL DOCENTE • PASO 1 DE 2', style: TextStyle(fontSize: 10, color: AppColors.verde, fontFamily: _mono)),
                ),
                Text('${(progreso * 100).round()}% Listo', style: const TextStyle(fontSize: 12, color: AppColors.gris, fontFamily: _mono)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progreso, minHeight: 5, color: AppColors.verde, backgroundColor: AppColors.borde),
              ),
              const SizedBox(height: 16),
              const Text('Registrar Nueva Asignatura', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Configura los parámetros del curso, horarios y carga masiva de alumnos matriculados.', style: TextStyle(fontSize: 12, color: AppColors.gris)),
            ]),
          ),

          // ── Datos de la materia
          _seccion(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titulo(Icons.menu_book, 'Datos de la Materia', chip: 'Semestre ${semestreActual()}'),
              const SizedBox(height: 16),
              _campo('Nombre de la Asignatura *', Icons.auto_stories_outlined, _nombre, hint: 'Física Mecánica y Termodinámica', cap: TextCapitalization.sentences),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _campo('Código Asignatura', Icons.tag, _codigo, hint: 'FIS-204', cap: TextCapitalization.characters)),
                const SizedBox(width: 10),
                Expanded(child: _campo('Grupo / Sección', Icons.groups_outlined, _grupo, hint: 'G-02', cap: TextCapitalization.characters)),
              ]),
              const SizedBox(height: 14),
              _campo('Total de sesiones del semestre *', Icons.event_repeat, _sesiones, hint: 'Ej. 30 (cada curso tiene las suyas)'),
            ]),
          ),

          // ── Horario y aula
          _seccion(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titulo(Icons.schedule, 'Horario & Aula Asignada'),
              const SizedBox(height: 16),
              _etiqueta('Días de Cátedra Presencial'),
              Row(children: [for (final d in _diasSemana) _diaChip(d)]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _horaCampo('Hora de Inicio', _inicio, true),
                const SizedBox(width: 10),
                _horaCampo('Hora de Salida', _fin, false),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _campo('Aula', Icons.meeting_room_outlined, _aula, hint: 'Aula 302')),
                const SizedBox(width: 10),
                Expanded(child: _campo('Edificio', Icons.apartment, _edificio, hint: 'Edificio B')),
              ]),
              const SizedBox(height: 14),
              _campo('Campus / Sede', Icons.location_city, _campus, hint: 'Campus Central Universitario'),
              const SizedBox(height: 14),
              _tarjetaAula(),
            ]),
          ),

          // ── Padrón
          _seccion(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titulo(Icons.upload_file, 'Padrón de Estudiantes', chip: 'Carga Masiva'),
              const SizedBox(height: 14),
              _zonaCarga(),
              _resultadoPadron(),
            ]),
          ),

          const SizedBox(height: 4),
          GestureDetector(
            onTap: _guardando ? null : () => _guardar(borrador: false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: AppColors.verde, borderRadius: BorderRadius.circular(30)),
              child: Center(
                child: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Crear Curso y Publicar Horario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18, color: Colors.black),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _guardando ? null : () => _guardar(borrador: true),
            child: const Text('Guardar como Borrador', style: TextStyle(color: AppColors.gris, fontFamily: _mono, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}