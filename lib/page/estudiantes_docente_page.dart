import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../providers/asistencia_provider.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/archivos.dart';
import '../src/inasistencias.dart';
import '../src/kampus_widgets.dart';
import 'estudiante/historial_justificaciones_page.dart';
import 'solicitudes_justificacion.dart';

const _ambar = Color(0xFFF5B942);
const _azul = Color(0xFF60A5FA);

int _faltas(Map e) => e['faltas'] as int;
// Límite dinámico: 20 % de las sesiones del curso (ver src/inasistencias.dart).
int _max(Map e) => (e['maxFaltas'] as int?) ?? 3;
bool _enRiesgo(Map e) => _faltas(e) >= _max(e) - 1;
bool _perdida(Map e) => perdioPorFallas(_faltas(e), _max(e));

String _fmtFecha(DateTime d) {
  const m = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${d.day} ${m[d.month - 1]}';
}

Widget _puntos(int faltas, int max) => Row(
  children: [
    for (var i = 0; i < max.clamp(0, 12); i++)
      Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < faltas ? AppColors.rojo : AppColors.borde,
        ),
      ),
  ],
);

/// Pestaña "Estudiantes": monitoreo de asistencia y riesgo por curso.
class EstudiantesDocente extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const EstudiantesDocente({super.key, required this.perfil});

  @override
  State<EstudiantesDocente> createState() => _EstudiantesDocenteState();
}

class _EstudiantesDocenteState extends State<EstudiantesDocente> {
  String? _cursoId;
  String _filtro = 'Todos';
  String _busqueda = '';
  Future<Map<String, dynamic>>? _futuro;
  String? _futuroDe;

  Future<Map<String, dynamic>> _resumen(String id) {
    if (_futuroDe != id || _futuro == null) {
      _futuroDe = id;
      _futuro = AsistenciaProvider.resumenCurso(id);
    }
    return _futuro!;
  }

  void _recargar() => setState(() => _futuro = null);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AsistenciaProvider.cursosDe(widget.perfil['uid'] as String),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.verde),
          );
        }
        final cursos =
            snap.data!.docs
                .where((d) => d.data()['estado'] != 'borrador')
                .toList()
              ..sort((a, b) => '${a['nombre']}'.compareTo('${b['nombre']}'));
        if (cursos.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              InfoBox(
                icono: Icons.groups_outlined,
                texto: 'Crea un curso con su padrón desde "Mis Cursos" para monitorear a tus estudiantes.',
              ),
            ],
          );
        }
        if (_cursoId == null || !cursos.any((c) => c.id == _cursoId)) {
          _cursoId = cursos.first.id;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SolicitudesJustificacion(docenteUid: widget.perfil['uid'] as String),
            const Text(
              'Gestión de Estudiantes',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Monitoreo de asistencia y riesgo por inasistencias',
              style: TextStyle(color: AppColors.gris, fontSize: 12),
            ),
            const SizedBox(height: 14),
            KampusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CÁTEDRA ACTIVA',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.gris,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _cursoId,
                    isExpanded: true,
                    dropdownColor: AppColors.tarjeta,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.campo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      for (final c in cursos)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c['nombre']} (G-${c['grupo']}) — ${c['aula']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _cursoId = v;
                      _futuro = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _resumen(_cursoId!),
                    builder: (context, r) {
                      if (r.hasError) {
                        return Text(
                          '${r.error}',
                          style: const TextStyle(color: AppColors.rojo),
                        );
                      }
                      if (!r.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.verde,
                            ),
                          ),
                        );
                      }
                      final est = (r.data!['estudiantes'] as List)
                          .cast<Map<String, dynamic>>();
                      final prom = est.isEmpty
                          ? 0.0
                          : est
                                    .map((e) => e['porcentaje'] as double)
                                    .reduce((a, b) => a + b) /
                                est.length;
                      return Row(
                        children: [
                          _mini(
                            '${est.length}',
                            'Total alumnos',
                            AppColors.texto,
                          ),
                          const SizedBox(width: 8),
                          _mini(
                            '${est.where(_enRiesgo).length}',
                            'En riesgo',
                            _ambar,
                          ),
                          const SizedBox(width: 8),
                          _mini(
                            '${prom.toStringAsFixed(1)}%',
                            'Promedio',
                            AppColors.verde,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _formAlumno(),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Agregar estudiante'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _ajustarTotal(cursos.firstWhere((c) => c.id == _cursoId).data()),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Total de sesiones'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistorialJustificacionesPage(docenteUid: widget.perfil['uid'] as String),
                    ),
                  ),
                  icon: const Icon(Icons.history_edu_outlined, size: 18),
                  label: const Text('Registro de justificaciones'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar alumno por nombre o ID…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.tarjeta,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _resumen(_cursoId!),
              builder: (context, r) {
                if (!r.hasData) return const SizedBox.shrink();
                final total = r.data!['total'] as int;
                final est = (r.data!['estudiantes'] as List)
                    .cast<Map<String, dynamic>>();
                final riesgo = est.where(_enRiesgo).length;
                final perfectos = total == 0
                    ? 0
                    : est
                          .where(
                            (e) =>
                                _faltas(e) == 0 && (e['tardanzas'] as int) == 0,
                          )
                          .length;
                final visibles = est.where((e) {
                  final q = _busqueda.toLowerCase();
                  final ok =
                      '${e['nombre']}'.toLowerCase().contains(q) ||
                      '${e['matricula']}'.toLowerCase().contains(q);
                  return ok &&
                      switch (_filtro) {
                        'En riesgo' => _enRiesgo(e),
                        'Asistencia perfecta' =>
                          total > 0 &&
                              _faltas(e) == 0 &&
                              (e['tardanzas'] as int) == 0,
                        _ => true,
                      };
                }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in [
                            ('Todos', est.length),
                            ('En riesgo', riesgo),
                            ('Asistencia perfecta', perfectos),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${f.$1} (${f.$2})'),
                                selected: _filtro == f.$1,
                                onSelected: (_) =>
                                    setState(() => _filtro = f.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (total == 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: InfoBox(
                          icono: Icons.info_outline,
                          texto: 'Aún no hay clases finalizadas. Las faltas se calculan al guardar el acta de cada sesión.',
                        ),
                      ),
                    if (visibles.isEmpty && est.isEmpty)
                      const InfoBox(
                        icono: Icons.groups_outlined,
                        texto: 'Este curso no tiene padrón cargado.',
                      ),
                    for (final e in visibles) _tarjeta(e, total),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _mini(String v, String t, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
          Text(t, style: const TextStyle(fontSize: 10, color: AppColors.gris)),
        ],
      ),
    ),
  );

  // ───────────── padrón manual (misma estructura del Excel) ─────────────
  Future<void> _formAlumno([Map<String, dynamic>? e]) async {
    final mat = TextEditingController(text: e == null ? '' : '${e['matricula']}');
    final nom = TextEditingController(text: e == null ? '' : '${e['nombre']}');
    final cor = TextEditingController(text: e == null ? '' : '${e['correo'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: Text(e == null ? 'Agregar estudiante' : 'Editar estudiante'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: mat, decoration: const InputDecoration(labelText: 'Matrícula')),
            TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nombre completo')),
            TextField(
              controller: cor,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo (opcional)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final m = mat.text, n = nom.text, c = cor.text;
    if (ok != true || !mounted) return;
    final msg = ScaffoldMessenger.of(context);
    try {
      await AsistenciaProvider.guardarEstudiante(
        _cursoId!,
        matricula: m,
        nombre: n,
        correo: c,
        matriculaOriginal: e == null ? null : '${e['matricula']}',
      );
      msg.showSnackBar(SnackBar(content: Text(e == null ? 'Estudiante agregado.' : 'Datos actualizados.')));
      _recargar();
    } on AuthException catch (x) {
      msg.showSnackBar(SnackBar(content: Text(x.mensaje)));
    }
  }

  Future<void> _eliminarAlumno(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Eliminar estudiante'),
        content: Text('¿Quitar a ${e['nombre']} (${e['matricula']}) de este curso? Su historial de sesiones anteriores se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: AppColors.rojo))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final msg = ScaffoldMessenger.of(context);
    try {
      await AsistenciaProvider.eliminarEstudiante(_cursoId!, '${e['matricula']}');
      msg.showSnackBar(const SnackBar(content: Text('Estudiante eliminado del curso.')));
      _recargar();
    } on AuthException catch (x) {
      msg.showSnackBar(SnackBar(content: Text(x.mensaje)));
    }
  }

  // ───────────── total de sesiones del semestre (límite 20 %) ─────────────
  Future<void> _ajustarTotal(Map<String, dynamic> curso) async {
    final actual = sesionesPlanificadas(curso);
    final ctrl = TextEditingController(text: actual > 0 ? '$actual' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Total de sesiones del curso'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Cuántas clases tiene este curso en el semestre. Si al final se dictaron menos '
            '(ej. 28 de 30), cámbialo a 28 y las fallas (20 %) se recalculan sobre ese total.',
            style: TextStyle(fontSize: 12, color: AppColors.gris),
          ),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sesiones totales'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final n = int.tryParse(ctrl.text.trim());
    if (ok != true || !mounted) return;
    final msg = ScaffoldMessenger.of(context);
    try {
      await AsistenciaProvider.actualizarSesionesPlanificadas(_cursoId!, n ?? 0);
      msg.showSnackBar(const SnackBar(content: Text('Total de sesiones actualizado.')));
      _recargar();
    } on AuthException catch (x) {
      msg.showSnackBar(SnackBar(content: Text(x.mensaje)));
    }
  }

  Widget _tarjeta(Map<String, dynamic> e, int totalSesiones) {
    final f = _faltas(e);
    final color = _perdida(e)
        ? AppColors.rojo
        : _enRiesgo(e)
        ? _ambar
        : AppColors.verde;
    final nombre = '${e['nombre']}';
    final iniciales = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistorialEstudiantePage(
              cursoId: _cursoId!,
              matricula: '${e['matricula']}',
            ),
          ),
        );
        _recargar();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(_enRiesgo(e) ? 140 : 50)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.campo,
                  child: Text(
                    iniciales,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'ID: ${e['matricula']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gris,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _perdida(e)
                        ? 'Pérdida Asig.'
                        : '${(e['porcentaje'] as double).toStringAsFixed(0)}% • $f/${_max(e)} Faltas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.tarjeta,
                  onSelected: (v) => v == 'editar' ? _formAlumno(e) : _eliminarAlumno(e),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar datos')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar del curso')),
                  ],
                ),
              ],
            ),
            if (totalSesiones > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.campo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _puntos(f, _max(e)),
                    Text(
                      _perdida(e)
                          ? 'Límite de faltas alcanzado'
                          : f == _max(e)
                          ? '1 más = Pérdida'
                          : 'Margen reglamentario',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _enRiesgo(e) ? color : AppColors.gris,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Historial de asistencia de un estudiante en un curso.
class HistorialEstudiantePage extends StatefulWidget {
  final String cursoId;
  final String matricula;
  const HistorialEstudiantePage({
    super.key,
    required this.cursoId,
    required this.matricula,
  });

  @override
  State<HistorialEstudiantePage> createState() =>
      _HistorialEstudiantePageState();
}

class _HistorialEstudiantePageState extends State<HistorialEstudiantePage> {
  late Future<Map<String, dynamic>> _futuro = AsistenciaProvider.resumenCurso(
    widget.cursoId,
  );
  String _filtro = 'Todas';
  Map<String, dynamic>? _datos; // última carga, para exportar

  /// Exporta el historial completo del estudiante a CSV (abre en Excel).
  Future<void> _exportar() async {
    final msg = ScaffoldMessenger.of(context);
    final r = _datos;
    if (r == null) return;
    try {
      final e = (r['estudiantes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((x) => x['matricula'] == widget.matricula, orElse: () => {});
      if (e.isEmpty) return;
      String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
      String dd(int n) => n.toString().padLeft(2, '0');
      String fh(DateTime? d) => d == null ? '' : '${dd(d.day)}/${dd(d.month)}/${d.year} ${dd(d.hour)}:${dd(d.minute)}';
      final f = _faltas(e), mx = _max(e);
      final b = StringBuffer()
        ..write('Curso;${q(r['cursoNombre'])}\r\n')
        ..write('Matrícula;${q(e['matricula'])}\r\n')
        ..write('Nombre;${q(e['nombre'])}\r\n')
        ..write('Correo;${q(e['correo'])}\r\n')
        ..write('Asistencia %;${(e['porcentaje'] as double).toStringAsFixed(1)}\r\n')
        ..write('Faltas;$f de $mx permitidas\r\n')
        ..write('Justificadas;${e['justificadas']}\r\n')
        ..write('Estado;${perdioPorFallas(f, mx) ? 'Pérdida' : f >= mx - 1 ? 'En riesgo' : 'Regular'}\r\n\r\n')
        ..write('Sesión;Fecha de la clase;Estado;Hora de registro;Distancia (m)\r\n');
      final hist = (e['historial'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < hist.length; i++) {
        final h = hist[i];
        b.write([
          i + 1,
          q(fh(h['fecha'] as DateTime?)),
          q(switch ('${h['estado']}') {
            'presente' => 'Presente',
            'tardanza' => 'Tardanza',
            'justificada' => 'Falta justificada',
            _ => 'Falta injustificada',
          }),
          q(fh(h['hora'] as DateTime?)),
          h['distancia'] ?? '',
        ].join(';'));
        b.write('\r\n');
      }
      final slug = '${e['nombre']}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final ok = await guardarArchivoTexto('historial_$slug.csv', b.toString());
      if (ok) msg.showSnackBar(const SnackBar(content: Text('Reporte guardado.')));
    } catch (_) {
      msg.showSnackBar(const SnackBar(content: Text('No se pudo guardar el reporte.')));
    }
  }

  /// Aviso preventivo automático al estudiante (panel y, si existe, correo).
  Future<void> _notificar(Map<String, dynamic> e, Map<String, dynamic> datos) async {
    final msg = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Notificación preventiva'),
        content: Text(
          'Se enviará un aviso automático a ${e['nombre']} con su estado de inasistencias '
          '(${_faltas(e)} de ${_max(e)} faltas permitidas).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AsistenciaProvider.enviarAvisoPreventivo(
        docenteUid: AuthProvider.usuarioActual?.uid ?? '',
        cursoId: widget.cursoId,
        cursoNombre: '${datos['cursoNombre']}',
        estudiante: e,
        faltas: _faltas(e),
        maxFaltas: _max(e),
      );
      msg.showSnackBar(const SnackBar(content: Text('Aviso preventivo enviado.')));
    } on AuthException catch (x) {
      msg.showSnackBar(SnackBar(content: Text(x.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Asistencia'),
        actions: [
          TextButton.icon(
            onPressed: _exportar,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Exportar'),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _futuro,
          builder: (context, r) {
            if (r.hasError) return Center(child: Text('${r.error}'));
            if (!r.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.verde),
              );
            }
            _datos = r.data;
            final total = r.data!['total'] as int;
            final e = (r.data!['estudiantes'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (x) => x['matricula'] == widget.matricula,
                  orElse: () => {},
                );
            if (e.isEmpty) {
              return const Center(child: Text('Estudiante no encontrado.'));
            }
            final hist = (e['historial'] as List)
                .cast<Map<String, dynamic>>()
                .reversed
                .toList();
            final faltas = _faltas(e);
            final just = e['justificadas'] as int;
            final color = _perdida(e)
                ? AppColors.rojo
                : _enRiesgo(e)
                ? _ambar
                : AppColors.verde;
            final visibles = hist
                .where(
                  (h) => switch (_filtro) {
                    'Faltas' => h['estado'] == 'falta',
                    'Justificadas' => h['estado'] == 'justificada',
                    _ => true,
                  },
                )
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${r.data!['cursoNombre']}'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.verde,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                KampusCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e['nombre']}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${e['matricula']}${'${e['correo']}'.isEmpty ? '' : ' • ${e['correo']}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gris,
                        ),
                      ),
                      if (_enRiesgo(e)) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: color, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _perdida(e)
                                    ? 'Pérdida por inasistencias'
                                    : 'En riesgo por inasistencias',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _dato(
                            'Asistencia',
                            '${(e['porcentaje'] as double).toStringAsFixed(1)}%',
                            AppColors.verde,
                          ),
                          const SizedBox(width: 8),
                          _dato(
                            'Faltas',
                            '$faltas / ${_max(e)}',
                            AppColors.rojo,
                          ),
                          const SizedBox(width: 8),
                          _dato('Justificadas', '$just', _azul),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Límite 20% de ${r.data!['totalSesiones']} sesiones • $total dictadas',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '$faltas/${_max(e)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gris,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _puntos(faltas, _max(e)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _notificar(e, r.data!),
                          icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                          label: const Text('Enviar notificación preventiva'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in [
                      ('Todas', hist.length),
                      ('Faltas', faltas),
                      ('Justificadas', just),
                    ])
                      ChoiceChip(
                        label: Text('${f.$1} (${f.$2})'),
                        selected: _filtro == f.$1,
                        onSelected: (_) => setState(() => _filtro = f.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visibles.isEmpty)
                  const InfoBox(
                    icono: Icons.history,
                    texto: 'Sin sesiones registradas para este filtro.',
                  ),
                for (final h in visibles) _sesion(h),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dato(String t, String v, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 10, color: AppColors.gris)),
          Text(
            v,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sesion(Map<String, dynamic> h) {
    final estado = '${h['estado']}';
    final (etiqueta, color) = switch (estado) {
      'falta' => ('Falta Injustificada', AppColors.rojo),
      'justificada' => ('Falta Justificada', _azul),
      'tardanza' => ('Tardanza', _ambar),
      _ => ('Presente', AppColors.verde),
    };
    final hora = h['hora'] as DateTime?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sesión ${h['sesion']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtFecha(h['fecha'] as DateTime),
                style: const TextStyle(fontSize: 12, color: AppColors.gris),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (estado == 'presente' || estado == 'tardanza')
            Text(
              'Marcó ${hora == null ? '--' : TimeOfDay.fromDateTime(hora).format(context)} • GPS ${h['distancia'] ?? '--'} m verificado',
              style: const TextStyle(fontSize: 12, color: AppColors.verde),
            )
          else if (estado == 'justificada')
            Text(
              '${h['motivo'] ?? 'Justificada'}',
              style: const TextStyle(fontSize: 12, color: _azul),
            )
          else ...[
            const Text(
              'Sin registro en rango en esta sesión',
              style: TextStyle(fontSize: 12, color: AppColors.rojo),
            ),
            const SizedBox(height: 2),
            const Text(
              'La justificación la presenta el estudiante desde su app; aquí solo la apruebas o rechazas.',
              style: TextStyle(fontSize: 11, color: AppColors.gris),
            ),
          ],
        ],
      ),
    );
  }
}