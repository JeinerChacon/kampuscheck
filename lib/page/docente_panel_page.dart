import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../providers/asistencia_provider.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import '../src/panel_base.dart';
import '../src/archivos.dart';
import '../src/horario.dart';
import '../src/inasistencias.dart';
import 'configurar_geocerca_page.dart';
import 'estudiantes_docente_page.dart';
import 'nuevo_curso_page.dart';
import 'sesion_asistencia_page.dart';
import 'soporte/soporte_ayuda_page.dart';

typedef Curso = QueryDocumentSnapshot<Map<String, dynamic>>;

class DocentePanelPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const DocentePanelPage({super.key, required this.perfil});

  @override
  State<DocentePanelPage> createState() => _DocentePanelPageState();
}

class _DocentePanelPageState extends State<DocentePanelPage> {
  int _tab = 0;

  // Sesiones en vivo por curso (para deshabilitar "Iniciar clase" si ya hay una).
  Map<String, ({String id, DateTime? cierra, bool pausada})> _vivo = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subVivo;
  Timer? _relojVivo;

  @override
  void initState() {
    super.initState();
    _subVivo = AsistenciaProvider.sesionesAbiertasDe(_uid).listen((snap) {
      final m = <String, ({String id, DateTime? cierra, bool pausada})>{};
      for (final d in snap.docs) {
        final data = d.data();
        final c = data['cierraEn'];
        m['${data['cursoId']}'] = (
          id: d.id,
          cierra: c is Timestamp ? c.toDate() : null,
          pausada: data['pausada'] == true,
        );
      }
      if (mounted) setState(() => _vivo = m);
    }, onError: (_) {});
    _relojVivo = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subVivo?.cancel();
    _relojVivo?.cancel();
    super.dispose();
  }

  /// Id de la sesión en vivo del curso (null si no hay o ya venció).
  String? _sesionVigente(String cursoId) {
    final v = _vivo[cursoId];
    if (v == null) return null;
    final vigente = v.pausada || (v.cierra != null && v.cierra!.isAfter(DateTime.now()));
    return vigente ? v.id : null;
  }

  /// ¿Estamos dentro del horario programado (±30 min)?
  bool _dentroDeHorario(Map<String, dynamic> d) {
    final ahora = DateTime.now();
    if (!cursoEsHoy(d, ahora)) return false;
    final i = horaInicioDe(d);
    final f = horaFinDe(d);
    if (i == null || f == null) return true;
    final ini = DateTime(ahora.year, ahora.month, ahora.day, i.$1, i.$2)
        .subtract(const Duration(minutes: 30));
    final fin = DateTime(ahora.year, ahora.month, ahora.day, f.$1, f.$2)
        .add(const Duration(minutes: 30));
    return ahora.isAfter(ini) && ahora.isBefore(fin);
  }
  static const _titulos = ['Mis Cursos', 'En Vivo', 'Estudiantes', 'Ajustes'];

  String get _uid => widget.perfil['uid'] as String;
  String get _nombre => (widget.perfil['nombre'] as String?) ?? 'Docente';

  // ───────────────────────── utilidades ─────────────────────────
  String _sinAcentos(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  bool _esHoy(Map<String, dynamic> c) {
    const dias = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
    final texto = _sinAcentos((c['dias'] as String?) ?? '');
    return texto.contains(dias[DateTime.now().weekday - 1]);
  }

  Widget _chip(String texto, {bool verde = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: verde ? AppColors.verde.withAlpha(30) : AppColors.campo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: verde ? AppColors.verde : AppColors.gris,
        ),
      ),
    );
  }

  // ───────────────────────── acciones ─────────────────────────
  Future<void> _nuevoCurso() async {
    final msg = ScaffoldMessenger.of(context);
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => NuevoCursoPage(perfil: widget.perfil)),
    );
    if (r == null) return;
    msg.showSnackBar(
      SnackBar(
        content: Text(
          r == 'borrador'
              ? 'Curso guardado como borrador.'
              : 'Curso creado y horario publicado.',
        ),
      ),
    );
  }

  /// Si el curso ya tiene sesión abierta vuelve a ella; si no, abre la configuración.
  Future<void> _abrirCurso(Curso curso) async {
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (curso.data()['estado'] == 'borrador') {
      msg.showSnackBar(
        const SnackBar(
          content: Text(
            'Este curso es un borrador. Complétalo para iniciar clase.',
          ),
        ),
      );
      return;
    }
    try {
      final abierta = await AsistenciaProvider.sesionAbierta(curso.id);
      if (abierta != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => SesionAsistenciaPage(sesionId: abierta),
          ),
        );
        return;
      }
      final d = curso.data();
      if (!_dentroDeHorario(d)) {
        if (!mounted) return;
        final seguir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.tarjeta,
            title: const Text('Clase fuera de horario'),
            content: Text(
              '${d['nombre']} está programada ${d['dias']} • ${d['horario']}.\n\n'
              '¿Quieres iniciarla ahora de todas formas?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Iniciar igual')),
            ],
          ),
        );
        if (seguir != true) return;
      }
      nav.push(
        MaterialPageRoute(
          builder: (_) => ConfigurarGeocercaPage(
            perfil: widget.perfil,
            cursoId: curso.id,
            curso: d,
          ),
        ),
      );
    } on AuthException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  // ───────────────────────── configuración y reportes ─────────────────────────
  String _resumenConfig(Map<String, dynamic> d) {
    final c = AsistenciaProvider.configDe(d);
    return 'Config. guardada: ${c['minutos']} min • ${c['radio']} m'
        '${c['biometria'] == true ? ' • biometría' : ''}';
  }

  /// Abre el panel de geocerca en modo "programar": se guarda en el curso y
  /// queda lista para todas sus próximas sesiones (se puede volver a editar).
  void _configurarCurso(Curso c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigurarGeocercaPage(
          perfil: widget.perfil,
          cursoId: c.id,
          curso: c.data(),
          modo: ModoGeocerca.programar,
        ),
      ),
    );
  }

  Future<Curso?> _elegirCurso(String titulo) async {
    final msg = ScaffoldMessenger.of(context);
    List<Curso> cursos;
    try {
      final snap = await AsistenciaProvider.cursosDe(_uid).first;
      cursos = snap.docs
          .where((d) => d.data()['estado'] != 'borrador')
          .toList();
    } catch (_) {
      msg.showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar tus cursos.')),
      );
      return null;
    }
    if (cursos.isEmpty) {
      msg.showSnackBar(
        const SnackBar(
          content: Text('Primero crea un curso con "+ Nuevo curso".'),
        ),
      );
      return null;
    }
    if (cursos.length == 1) return cursos.first;
    if (!mounted) return null;
    return showModalBottomSheet<Curso>(
      context: context,
      backgroundColor: AppColors.tarjeta,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final c in cursos)
              ListTile(
                title: Text('${c['nombre']}'),
                subtitle: Text('${c['aula']} • ${c['dias']} • ${c['horario']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _atajoPerimetro() async {
    final c = await _elegirCurso('¿Qué curso quieres configurar?');
    if (c == null || !mounted) return;
    _configurarCurso(c);
  }

  Future<void> _exportar() async {
    final msg = ScaffoldMessenger.of(context);
    final c = await _elegirCurso('¿Qué curso quieres exportar?');
    if (c == null) return;
    try {
      final r = await AsistenciaProvider.resumenCurso(c.id);
      final est = (r['estudiantes'] as List).cast<Map<String, dynamic>>();
      String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
      final b = StringBuffer(
        'Matrícula;Nombre;Correo;Presentes;Tardanzas;Faltas;Justificadas;Asistencia %;Estado\r\n',
      );
      for (final e in est) {
        final f = e['faltas'] as int;
        b.write(
          [
            q(e['matricula']),
            q(e['nombre']),
            q(e['correo']),
            e['presentes'],
            e['tardanzas'],
            f,
            e['justificadas'],
            (e['porcentaje'] as double).toStringAsFixed(1),
            q(
              perdioPorFallas(f, e['maxFaltas'] as int)
                  ? 'Pérdida'
                  : f >= (e['maxFaltas'] as int) - 1
                  ? 'En riesgo'
                  : 'Regular',
            ),
          ].join(';'),
        );
        b.write('\r\n');
      }
      final slug = '${c['nombre']}'.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
      final ok = await guardarArchivoTexto(
        'asistencia_$slug.csv',
        b.toString(),
      );
      if (ok) {
        msg.showSnackBar(
          SnackBar(
            content: Text(
              'Reporte guardado: ${est.length} estudiantes, ${r['total']} clases.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      msg.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el reporte.')),
      );
    }
  }

  // ───────────────────────── pestaña: MIS CURSOS ─────────────────────────
  Widget _tarjetaPerfil() {
    return KampusCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.campo,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.verde, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombre,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Docente • ${widget.perfil['departamento'] ?? '---'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.gris),
                ),
                Text(
                  'ID: ${widget.perfil['codigoEmpleado'] ?? '---'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.verde),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaDestacada(Curso c, ProximaClase p) {
    final d = c.data();
    return KampusCard(
      borderColor: AppColors.verde.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chip(
                p.esHoy
                    ? (p.enCurso
                          ? '● EN CURSO HOY'
                          : '● LISTA PARA INICIAR HOY')
                    : '● PRÓXIMA CLASE • ${p.cuando}',
                verde: true,
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.gris,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${d['horario']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d['nombre']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _chip('Grupo ${d['grupo']}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${d['aula']} • ${d['edificio']}',
            style: const TextStyle(fontSize: 13, color: AppColors.gris),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Matriculados confirmados',
                      style: TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${d['alumnos'] ?? 0} Alumnos',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  value: 1,
                  minHeight: 5,
                  color: AppColors.verde,
                  backgroundColor: AppColors.borde,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_sesionVigente(c.id) != null) ...[
            // Ya hay una clase en vivo: no se puede iniciar otra, solo volver a ella.
            PrimaryButton(
              texto: 'Clase en curso • Ver sesión',
              icono: Icons.sensors,
              onPressed: () => _abrirCurso(c),
            ),
            const SizedBox(height: 8),
          ] else if (p.esHoy) ...[
            PrimaryButton(
              texto: 'Iniciar Clase y Abrir Asistencia',
              icono: Icons.play_arrow,
              onPressed: () => _abrirCurso(c),
            ),
            const SizedBox(height: 8),
          ] else ...[
            PrimaryButton(
              texto: 'Iniciar clase fuera de horario',
              icono: Icons.schedule,
              onPressed: () => _abrirCurso(c),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: AppColors.gris),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _resumenConfig(d),
                  style: const TextStyle(fontSize: 11, color: AppColors.gris),
                ),
              ),
              TextButton(
                onPressed: () => _configurarCurso(c),
                child: const Text('Ajustar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icono,
    String valor,
    String etiqueta, {
    Color color = AppColors.texto,
  }) {
    return Expanded(
      child: KampusCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icono, color: AppColors.verde, size: 22),
            const SizedBox(height: 8),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.gris),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaCurso(Curso c) {
    final d = c.data();
    return GestureDetector(
      onTap: () => _abrirCurso(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${d['nombre']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _chip('${d['codigo'] ?? ''} G-${d['grupo']}'.trim()),
                const Spacer(),
                if (d['estado'] == 'borrador')
                  _chip('Borrador')
                else if (_sesionVigente(c.id) != null)
                  _chip('● En vivo', verde: true)
                else if (_esHoy(d))
                  _chip('Hoy', verde: true),
                if (d['estado'] != 'borrador') ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _configurarCurso(c),
                    child: const Icon(
                      Icons.tune,
                      size: 19,
                      color: AppColors.gris,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${d['aula']} • ${d['edificio']}',
              style: const TextStyle(fontSize: 13, color: AppColors.gris),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.gris,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${d['dias']} • ${d['horario']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.gris),
                  ),
                ),
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppColors.verde,
                ),
                const SizedBox(width: 4),
                Text(
                  '${d['alumnos'] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _atajo(IconData icono, String titulo, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.campo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: AppColors.verde, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: AppColors.gris),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gris),
          ],
        ),
      ),
    );
  }

  Widget _etiquetaSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          color: AppColors.gris,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tabCursos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AsistenciaProvider.cursosDe(_uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar los cursos.\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.rojo),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.verde),
          );
        }
        final cursos = snap.data!.docs.toList()
          ..sort((a, b) {
            final bb =
                (a.data()['estado'] == 'borrador' ? 1 : 0) -
                (b.data()['estado'] == 'borrador' ? 1 : 0);
            if (bb != 0) return bb;
            final h = (_esHoy(b.data()) ? 1 : 0) - (_esHoy(a.data()) ? 1 : 0);
            return h != 0
                ? h
                : (a['nombre'] as String).compareTo(b['nombre'] as String);
          });
        final alumnos = cursos.fold<int>(
          0,
          (suma, c) => suma + ((c.data()['alumnos'] as num?)?.toInt() ?? 0),
        );
        final proxima = proximaClase([
          for (final c in cursos) {...c.data(), 'id': c.id},
        ]);
        final destacado = proxima == null
            ? null
            : cursos.firstWhere((c) => c.id == proxima.curso['id']);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tarjetaPerfil(),
            const SizedBox(height: 14),
            if (destacado != null) ...[
              _tarjetaDestacada(destacado, proxima!),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                _stat(Icons.menu_book, '${cursos.length}', 'Cursos Activos'),
                const SizedBox(width: 10),
                _stat(
                  Icons.fact_check_outlined,
                  '--',
                  'Asist. Promedio',
                  color: AppColors.verde,
                ),
                const SizedBox(width: 10),
                _stat(Icons.groups, '$alumnos', 'Alumnos Totales'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.list_alt, color: AppColors.verde, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cursos Asignados',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: _nuevoCurso,
                  child: _chip('+ Nuevo curso', verde: true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cursos.isEmpty)
              const InfoBox(
                icono: Icons.info_outline,
                texto: 'Aún no tienes cursos. Toca "+ Nuevo curso" para crear el primero.',
              ),
            for (final c in cursos) _tarjetaCurso(c),
            const SizedBox(height: 10),
            _etiquetaSeccion('GESTIÓN RÁPIDA'),
            _atajo(
              Icons.history,
              'Historial de Asistencias',
              'Consultar bitácora de faltas por estudiante',
              () => setState(() => _tab = 2),
            ),
            _atajo(
              Icons.download,
              'Exportar Reporte (Excel / CSV)',
              'Asistencia por curso lista para secretaría',
              _exportar,
            ),
            _atajo(
              Icons.tune,
              'Configurar Perímetro Predeterminado',
              'Ventana, radio y seguridad por curso',
              _atajoPerimetro,
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────── pestaña: EN VIVO ─────────────────────────
  Widget _tabEnVivo() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AsistenciaProvider.sesionesAbiertasDe(_uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.verde),
          );
        }
        final abiertas = snap.data!.docs
            .where((d) {
              final data = d.data();
              final cierra = data['cierraEn']; // puede faltar en sesiones antiguas
              return data['pausada'] == true ||
                  (cierra is Timestamp && cierra.toDate().isAfter(DateTime.now()));
            })
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (abiertas.isEmpty)
              const InfoBox(
                icono: Icons.sensors_off,
                texto: 'No tienes sesiones de asistencia activas. Inicia una desde "Mis Cursos".',
              ),
            for (final s in abiertas) ...[
              KampusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chip(
                      s.data()['pausada'] == true ? '● PAUSADA' : '● EN CURSO',
                      verde: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${s['cursoNombre']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${s['codigo']} • Radio ${s['radio']} m',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.gris,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      texto: 'Ver sesión',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SesionAsistenciaPage(sesionId: s.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  // ───────────────────────── pestañas: ESTUDIANTES / AJUSTES ─────────────────────────
  Widget _tabEstudiantes() {
    return EstudiantesDocente(perfil: widget.perfil);
  }

  Widget _tabAjustes() => _PerfilDocente(
    perfil: widget.perfil,
    onCerrarSesion: AuthProvider.cerrarSesion,
    onGeocerca: _atajoPerimetro,
  );

  // ───────────────────────── build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    // Construir únicamente la pestaña visible evita mantener árboles de
    // StreamBuilder/Scaffold ocultos mientras cambia el índice del menú.
    final Widget cuerpo = switch (_tab) {
      0 => _tabCursos(),
      1 => _tabEnVivo(),
      2 => _tabEstudiantes(),
      _ => _tabAjustes(),
    };

    return PanelBase(
      titulo: _titulos[_tab],
      icono: Icons.badge,
      saludo: 'Hola, $_nombre',
      detalle: 'Código: ${widget.perfil['codigoEmpleado'] ?? '---'}',
      acciones: [
        GestureDetector(
          onTap: () => setState(() => _tab = 3),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.verde,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
      ],
      cuerpo: cuerpo,
      bottomNav: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.tarjeta,
        selectedItemColor: AppColors.verde,
        unselectedItemColor: AppColors.gris,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Mis Cursos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'En Vivo'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Estudiantes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Ajustes'),
        ],
      ),
    );
  }
}

// ───────────────────── PERFIL Y CONFIGURACIÓN ─────────────────────
class _PerfilDocente extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final Future<void> Function() onCerrarSesion;
  final VoidCallback onGeocerca;
  const _PerfilDocente({
    required this.perfil,
    required this.onCerrarSesion,
    required this.onGeocerca,
  });
  @override
  State<_PerfilDocente> createState() => _PerfilDocenteState();
}

class _PerfilDocenteState extends State<_PerfilDocente> {
  late bool notificaciones = _pref('notificaciones');
  late bool alertas = _pref('alertas');

  bool _pref(String clave) {
    final m = widget.perfil['preferencias'];
    return m is Map ? (m[clave] as bool? ?? true) : true;
  }

  Future<void> _guardarPref(String clave, bool valor) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.perfil['uid'] as String)
          .set({
            'preferencias': {clave: valor},
          }, SetOptions(merge: true));
    } catch (_) {
      msg.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la preferencia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Perfil y Ajustes',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        KampusCard(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.campo,
                child: Icon(Icons.person, size: 42, color: AppColors.verde),
              ),
              const SizedBox(height: 12),
              Text(
                '${p['nombre'] ?? 'Docente'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Docente • ${p['departamento'] ?? 'Facultad'}',
                style: const TextStyle(color: AppColors.gris, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${p['codigoEmpleado'] ?? '---'}',
                style: const TextStyle(color: AppColors.verde),
              ),
              Text(
                '${p['correo'] ?? '---'}',
                style: const TextStyle(color: AppColors.gris, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Chip(label: Text('Docente activo')),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'SEGURIDAD DE LA CUENTA',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.gris,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        KampusCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline, color: AppColors.verde),
                title: const Text('Cambiar contraseña'),
                subtitle: const Text('Te enviaremos un enlace a tu correo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final msg = ScaffoldMessenger.of(context);
                  final correo = '${p['correo'] ?? ''}';
                  try {
                    await AuthProvider.enviarRecuperacion(correo);
                    msg.showSnackBar(
                      SnackBar(content: Text('Enlace enviado a $correo')),
                    );
                  } on AuthException catch (e) {
                    msg.showSnackBar(SnackBar(content: Text(e.mensaje)));
                  }
                },
              ),
              const Divider(),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.devices, color: AppColors.verde),
                title: Text('Dispositivos autorizados'),
                subtitle: Text('Protección de la cuenta'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'PREFERENCIAS DE CÁTEDRA Y SISTEMA',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.gris,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        KampusCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificaciones,
                onChanged: (v) {
                  setState(() => notificaciones = v);
                  _guardarPref('notificaciones', v);
                },
                activeThumbColor: AppColors.verde,
                title: const Text('Notificaciones de asistencia'),
                subtitle: const Text(
                  'Avisos cuando un alumno registre asistencia',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: alertas,
                onChanged: (v) {
                  setState(() => alertas = v);
                  _guardarPref('alertas', v);
                },
                activeThumbColor: AppColors.verde,
                title: const Text('Alertas de inasistencia crítica'),
                subtitle: const Text('Aviso al alcanzar el límite de faltas'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location, color: AppColors.verde),
                title: const Text('Ajustes avanzados de geocerca'),
                subtitle: const Text('Ventana, radio y seguridad por curso'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onGeocerca,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        KampusCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.support_agent,
                  color: AppColors.verde,
                ),
                title: const Text('Soporte académico y mesa de ayuda'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SoporteAyudaPage(perfil: widget.perfil),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          texto: 'Cerrar sesión',
          icono: Icons.logout,
          onPressed: () => widget.onCerrarSesion(),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'KampusCheck • Terminal Docente Segura',
            style: TextStyle(fontSize: 11, color: AppColors.gris),
          ),
        ),
      ],
    );
  }
}