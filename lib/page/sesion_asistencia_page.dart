import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/asistencia_provider.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import 'solicitudes_justificacion.dart';

/// Clase en vivo: ventana temporal, controles, estadísticas y registro en tiempo real.
class SesionAsistenciaPage extends StatefulWidget {
  final String sesionId;
  const SesionAsistenciaPage({super.key, required this.sesionId});

  @override
  State<SesionAsistenciaPage> createState() => _SesionAsistenciaPageState();
}

class _SesionAsistenciaPageState extends State<SesionAsistenciaPage> {
  Timer? _timer;
  Timer? _qrTimer;
  Map<String, dynamic>? _s; // última versión de la sesión
  List<Map<String, dynamic>> _padron = [];
  bool _padronCargado = false;
  bool _cerrando = false;
  String _filtro = 'Todos';
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    // QR dinámico: se renueva cada 60 s mientras esta pantalla está abierta.
    AsistenciaProvider.rotarQr(widget.sesionId);
    _qrTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final s = _s;
      if (mounted && s != null && s['estado'] == 'abierta' && s['pausada'] != true) {
        AsistenciaProvider.rotarQr(widget.sesionId);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = _s;
      if (!mounted || s == null) return;
      setState(() {});
      if (s['estado'] == 'abierta' &&
          s['pausada'] != true &&
          _restante(s) == Duration.zero &&
          !_cerrando) {
        _cerrando = true;
        AsistenciaProvider.cerrarSesion(widget.sesionId);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _qrTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarPadron(String cursoId) async {
    _padronCargado = true;
    final c = await AsistenciaProvider.curso(cursoId);
    if (!mounted) return;
    setState(
      () => _padron = ((c?['estudiantes'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Duration _restante(Map<String, dynamic> s) {
    final cierra = (s['cierraEn'] as Timestamp).toDate();
    final ref = s['pausada'] == true
        ? (s['pausadaEn'] as Timestamp?)?.toDate() ?? DateTime.now()
        : DateTime.now();
    final r = cierra.difference(ref);
    return r.isNegative ? Duration.zero : r;
  }

  String _mmss(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } on AuthException catch (e) {
      if (mounted) _aviso(e.mensaje);
    }
  }

  Future<bool> _confirmar(String titulo, String texto, String ok) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.tarjeta,
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ok),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _finalizar(int presentes, int ausentes) async {
    final ok = await _confirmar(
      'Finalizar clase y guardar acta',
      '$presentes presentes • $ausentes ausentes.\nQuienes no marcaron quedarán con falta. Esta acción no se puede deshacer.',
      'Guardar acta',
    );
    if (!ok) return;
    _cerrando = true;
    await _run(() => AsistenciaProvider.cerrarSesion(widget.sesionId));
    if (mounted) {
      _aviso('Acta guardada.');
      Navigator.pop(context);
    }
  }

  Future<void> _expulsar(String uid, String nombre) async {
    final ok = await _confirmar(
      'Expulsar de la sesión',
      '¿Anular el check-in de $nombre? No podrá volver a marcar en esta sesión.',
      'Expulsar',
    );
    if (ok) await _run(() => AsistenciaProvider.expulsar(widget.sesionId, uid));
  }

  // ───────────────────────── widgets ─────────────────────────
  Widget _chip(String t, {Color color = AppColors.verde}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _boton(
    IconData i,
    String t,
    VoidCallback? onTap, {
    Color color = AppColors.texto,
  }) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.campo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(i, size: 18, color: onTap == null ? AppColors.gris : color),
            const SizedBox(height: 4),
            Text(
              t,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onTap == null ? AppColors.gris : color,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tarjetaQr(Map<String, dynamic> s, String codigo) {
    final token = '${s['qrToken'] ?? ''}';
    return KampusCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2, color: AppColors.verde, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('QR dinámico de asistencia',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Cambia cada 1 min. Proyéctalo para que los estudiantes lo escaneen.',
                style: TextStyle(fontSize: 11, color: AppColors.gris)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: token.isEmpty
                ? const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : QrImageView(
                    data: 'KAMPUS|${widget.sesionId}|$token',
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Código manual: ${codigo.substring(0, 3)} ${codigo.substring(3)}',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData i,
    String v,
    String t, {
    Color color = AppColors.texto,
  }) => Expanded(
    child: KampusCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Icon(i, color: AppColors.verde, size: 20),
          const SizedBox(height: 6),
          Text(
            v,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            t,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.gris),
          ),
        ],
      ),
    ),
  );

  Widget _filaAlumno(Map<String, dynamic> a, bool abierta, bool biometria) {
    final estado = a['estado'] as String;
    final h = (a['hora'] as Timestamp?)?.toDate();
    final color = switch (estado) {
      'presente' => AppColors.verde,
      'tardanza' => const Color(0xFFF5B942),
      'justificada' => const Color(0xFF60A5FA),
      _ => AppColors.rojo,
    };
    final etiqueta = switch (estado) {
      'presente' => 'Puntual',
      'tardanza' => 'Tardanza',
      'justificada' => 'Justificada',
      'pendiente' => 'Pendiente',
      _ => 'Falta',
    };
    final registrado = estado == 'presente' || estado == 'tardanza';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.campo,
                child: Text(
                  ((a['nombre'] ?? '?') as String).isEmpty
                      ? '?'
                      : (a['nombre'] as String)[0].toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['nombre']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'ID #${a['matricula'] ?? '---'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gris,
                      ),
                    ),
                    if (registrado)
                      Text(
                        '${h == null ? '--' : TimeOfDay.fromDateTime(h).format(context)} • ${a['distancia'] ?? '--'} m',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.verde,
                        ),
                      ),
                  ],
                ),
              ),
              _chip(
                etiqueta,
                color: estado == 'pendiente' ? AppColors.gris : color,
              ),
              if (registrado && abierta)
                IconButton(
                  tooltip: 'Expulsar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.person_remove_alt_1,
                    color: AppColors.rojo,
                    size: 20,
                  ),
                  onPressed: () =>
                      _expulsar(a['uid'] as String, '${a['nombre']}'),
                ),
            ],
          ),
          if (registrado) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.campo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: AppColors.verde,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Verificado GPS',
                        style: TextStyle(fontSize: 11, color: AppColors.verde),
                      ),
                    ],
                  ),
                  if (biometria)
                    const Text(
                      'Biometría OK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clase En Vivo')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AsistenciaProvider.sesion(widget.sesionId),
          builder: (context, snap) {
            final s = snap.data?.data();
            if (s == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.verde),
              );
            }
            _s = s;
            if (!_padronCargado) _cargarPadron(s['cursoId'] as String);
            final abierta = s['estado'] == 'abierta';
            final pausada = s['pausada'] == true;
            final codigo = s['codigo'] as String;
            final restante = _restante(s);
            final inicio = (s['inicioLocal'] as Timestamp?)?.toDate();
            final cierra = (s['cierraEn'] as Timestamp).toDate();
            final totalVentana = inicio == null
                ? 1
                : cierra.difference(inicio).inSeconds.clamp(1, 1 << 30).toInt();
            final progreso = abierta
                ? (restante.inSeconds / totalVentana).clamp(0.0, 1.0).toDouble()
                : 0.0;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AsistenciaProvider.asistentes(widget.sesionId),
              builder: (context, a) {
                final docs = a.data?.docs ?? [];
                final todos = <Map<String, dynamic>>[
                  for (final d in docs)
                    {
                      ...d.data(),
                      'uid': d.id,
                      'estado': (d.data()['estado'] ?? 'presente').toString(),
                    },
                ];
                final marcaron = todos.map((e) => '${e['matricula']}').toSet();
                if (abierta) {
                  for (final p in _padron) {
                    if (!marcaron.contains('${p['matricula']}')) {
                      todos.add({
                        'uid': 'p_${p['matricula']}',
                        'nombre': p['nombre'],
                        'matricula': p['matricula'],
                        'estado': 'pendiente',
                      });
                    }
                  }
                }
                todos.sort((x, y) {
                  int rank(Map e) =>
                      (e['estado'] == 'presente' || e['estado'] == 'tardanza')
                      ? 0
                      : 1;
                  final r = rank(x).compareTo(rank(y));
                  if (r != 0) return r;
                  final hx = (x['hora'] as Timestamp?)?.toDate();
                  final hy = (y['hora'] as Timestamp?)?.toDate();
                  if (hx != null && hy != null) {
                    return hy.compareTo(hx); // más recientes primero
                  }
                  return '${x['nombre']}'.compareTo('${y['nombre']}');
                });

                final puntuales = todos
                    .where((e) => e['estado'] == 'presente')
                    .length;
                final tardanzas = todos
                    .where((e) => e['estado'] == 'tardanza')
                    .length;
                final presentes = puntuales + tardanzas;
                final ausentes = todos
                    .where(
                      (e) =>
                          e['estado'] == 'pendiente' || e['estado'] == 'falta',
                    )
                    .length;
                final total = _padron.isEmpty ? presentes : _padron.length;
                final pct = total == 0 ? 0 : (presentes * 100 / total).round();

                final visibles = todos.where((e) {
                  final q = _busqueda.toLowerCase();
                  final coincide =
                      '${e['nombre']}'.toLowerCase().contains(q) ||
                      '${e['matricula']}'.toLowerCase().contains(q);
                  final ok = switch (_filtro) {
                    'Puntuales' => e['estado'] == 'presente',
                    'Tardanzas' => e['estado'] == 'tardanza',
                    'Ausentes' =>
                      e['estado'] == 'pendiente' || e['estado'] == 'falta',
                    _ => true,
                  };
                  return coincide && ok;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── sesión activa
                    KampusCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '● SESIÓN ACTIVA',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gris,
                                  letterSpacing: 1,
                                ),
                              ),
                              _chip(
                                !abierta
                                    ? 'CERRADA'
                                    : pausada
                                    ? 'PAUSADA'
                                    : 'EN VIVO • REGISTRO ACTIVO',
                                color: !abierta
                                    ? AppColors.rojo
                                    : pausada
                                    ? const Color(0xFFF5B942)
                                    : AppColors.verde,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${s['cursoNombre']}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ('${s['aula'] ?? ''}'.isNotEmpty)
                            Text(
                              '${s['aula']} • ${s['edificio'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.gris,
                              ),
                            ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: codigo));
                              _aviso('Código copiado');
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.pin_outlined,
                                  size: 16,
                                  color: AppColors.gris,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Código ${codigo.substring(0, 3)} ${codigo.substring(3)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: abierta
                                        ? AppColors.verde
                                        : AppColors.gris,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.campo,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Ventana temporal: ${_mmss(restante)} min',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.verde,
                                      ),
                                    ),
                                    _chip(
                                      'Geocerca: ${s['radio']}m',
                                      color: AppColors.gris,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: progreso,
                                  minHeight: 5,
                                  color: AppColors.verde,
                                  backgroundColor: AppColors.borde,
                                ),
                                if (abierta) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _boton(
                                        pausada
                                            ? Icons.play_arrow
                                            : Icons.pause,
                                        pausada ? 'Reanudar' : 'Pausar',
                                        () => _run(
                                          () => pausada
                                              ? AsistenciaProvider.reanudar(
                                                  widget.sesionId,
                                                )
                                              : AsistenciaProvider.pausar(
                                                  widget.sesionId,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _boton(
                                        Icons.more_time,
                                        '+5 Min',
                                        () => _run(
                                          () => AsistenciaProvider.extender(
                                            widget.sesionId,
                                            5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _boton(
                                        Icons.lock_outline,
                                        'Cerrar',
                                        () => _finalizar(presentes, ausentes),
                                        color: AppColors.rojo,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (abierta) ...[
                      _tarjetaQr(s, codigo),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        _stat(
                          Icons.how_to_reg,
                          '$presentes/$total',
                          'Presentes ($pct%)',
                          color: AppColors.verde,
                        ),
                        const SizedBox(width: 8),
                        _stat(
                          Icons.pending_actions,
                          '${abierta ? ausentes : 0}',
                          'Pendientes',
                        ),
                        const SizedBox(width: 8),
                        _stat(
                          Icons.location_off,
                          '${s['fueraRango'] ?? 0}',
                          'Fuera de rango',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _busqueda = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar alumno por nombre o carnet…',
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in [
                            ('Todos', todos.length),
                            ('Puntuales', puntuales),
                            ('Tardanzas', tardanzas),
                            ('Ausentes', ausentes),
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
                    Text(
                      'REGISTRO EN TIEMPO REAL ●',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: abierta ? AppColors.verde : AppColors.gris,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (visibles.isEmpty)
                      const InfoBox(
                        icono: Icons.hourglass_empty,
                        texto: 'Sin resultados. Esperando a los estudiantes…',
                      ),
                    for (final e in visibles)
                      _filaAlumno(e, abierta, s['biometria'] == true),
                    if (abierta)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: InfoBox(
                          icono: Icons.info_outline,
                          texto: '¿No ves a un alumno en su banca? Usa Expulsar para anular su check-in por ausencia presencial.',
                        ),
                      ),
                    const SizedBox(height: 14),
                    SolicitudesJustificacion(
                      docenteUid: '${s['docenteUid']}',
                      cursoId: '${s['cursoId']}',
                    ),
                    PrimaryButton(
                      texto: abierta
                          ? 'Finalizar Clase y Guardar Acta'
                          : 'Volver',
                      icono: abierta
                          ? Icons.fact_check_outlined
                          : Icons.arrow_back,
                      onPressed: abierta
                          ? () => _finalizar(presentes, ausentes)
                          : () => Navigator.pop(context),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}