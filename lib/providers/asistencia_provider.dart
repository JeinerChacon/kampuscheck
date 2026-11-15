import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:geolocator/geolocator.dart';
import '../src/dispositivo.dart';
import '../src/horario.dart';
import '../src/inasistencias.dart';
import '../src/validadores.dart';
import 'auth_provider.dart';

/// Error al registrar asistencia, con el motivo para poder mostrar el diagnóstico.
/// tipo: codigo | cerrada | pausada | expulsado | padron | duplicada | gps | mock | distancia | dispositivo
class AsistenciaError extends AuthException {
  final String tipo;
  final int? distancia; // metros al punto del docente (tipo distancia)
  final int? radio; // radio permitido (tipo distancia)
  AsistenciaError(super.mensaje, this.tipo, {this.distancia, this.radio});
}

/// Cursos, sesiones de asistencia y geocerca.
///
/// Firestore:
///  cursos/{id}   -> docenteUid, nombre, codigo, grupo, semestre, aula, edificio,
///                   dias ("Lun/Mié/Vie"), diasLista, horaInicio, horaFin, horario,
///                   radio, estado (activo|borrador), alumnos, estudiantes[{matricula,nombre,correo}],
///                   matriculas[]
///  sesiones/{id} -> cursoId, cursoNombre, aula, edificio, docenteUid, codigo, lat, lng, radio,
///                   estado (abierta|cerrada), pausada, pausadaEn, inicioLocal, cierraEn,
///                   expulsados[], fueraRango
///  sesiones/{id}/asistencias/{uid | m_matricula}
///                -> nombre, matricula, estado (presente|tardanza|falta|justificada),
///                   hora, distancia, motivo
class AsistenciaProvider {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// La pérdida por fallas (20 %) se calcula por curso: ver src/inasistencias.dart.
  static const int minutosTardanza = 10;

  static Future<T> _seguro<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseException catch (e) {
      throw AuthException('Error con la base de datos (${e.code}).');
    }
  }

  // ───────────────────────── UBICACIÓN ─────────────────────────
  static Future<Position> obtenerUbicacion() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AuthException('Activa el GPS de tu dispositivo.');
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw AuthException('Necesitamos el permiso de ubicación.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw AuthException(
          'Permiso de ubicación bloqueado. Actívalo en Ajustes del teléfono.');
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      throw AuthException('No se pudo obtener tu ubicación. Intenta de nuevo.');
    }
  }

  // ─────────────────────────── CURSOS ───────────────────────────
  static Stream<QuerySnapshot<Map<String, dynamic>>> cursosDe(String uid) =>
      _db.collection('cursos').where('docenteUid', isEqualTo: uid).snapshots();

  /// Configuración de asistencia por defecto de un curso (ventana, radio, seguridad).
  static Map<String, dynamic> configNormalizada(Map<String, dynamic>? c) {
    final minutos = (c?['minutos'] as num?)?.toInt() ?? 15;
    final radio = (c?['radio'] as num?)?.toInt() ?? 10;
    return {
      'minutos': minutos.clamp(1, 180),
      'radio': const [5, 10, 15].contains(radio) ? radio : 10,
      'biometria': c?['biometria'] as bool? ?? true,
      'estricto': c?['estricto'] as bool? ?? true,
    };
  }

  /// Lee la configuración guardada del curso (o los valores por defecto).
  static Map<String, dynamic> configDe(Map<String, dynamic> curso) =>
      configNormalizada(curso['config'] is Map
          ? Map<String, dynamic>.from(curso['config'] as Map)
          : {'radio': curso['radio']});

  /// Guarda la configuración: queda programada para las próximas sesiones del curso.
  static Future<void> guardarConfig(
          String cursoId, Map<String, dynamic> config) =>
      _seguro(() {
        final c = configNormalizada(config);
        return _db.collection('cursos').doc(cursoId).update({
          'config': c,
          'radio': c['radio'],
          'configActualizadaEn': FieldValue.serverTimestamp(),
        });
      });

  static Future<Map<String, dynamic>?> curso(String id) => _seguro(() async =>
      (await _db.collection('cursos').doc(id).get()).data());

  static Future<void> crearCurso({
    required String docenteUid,
    String docenteNombre = '',
    required String nombre,
    String codigo = '',
    String grupo = '',
    String semestre = '',
    required String aula,
    required String edificio,
    String campus = '',
    required List<String> dias,
    required String horaInicio,
    required String horaFin,
    Map<String, dynamic>? config,
    List<Map<String, String>> estudiantes = const [],
    int sesionesPlanificadas = 0,
    bool borrador = false,
  }) =>
      _seguro(() => _db.collection('cursos').add({
            'docenteUid': docenteUid,
            'docenteNombre': docenteNombre.trim(),
            'nombre': nombre.trim(),
            'codigo': codigo.trim().toUpperCase(),
            'grupo': grupo.trim(),
            'semestre': semestre,
            'aula': aula.trim(),
            'edificio': edificio.trim(),
            'campus': campus.trim(),
            'dias': dias.join('/'),
            'diasLista': dias,
            'horaInicio': horaInicio,
            'horaFin': horaFin,
            'horario': '$horaInicio - $horaFin',
            'config': configNormalizada(config),
            'radio': configNormalizada(config)['radio'],
            'sesionesPlanificadas': sesionesPlanificadas,
            'estado': borrador ? 'borrador' : 'activo',
            'alumnos': estudiantes.length,
            'estudiantes': estudiantes,
            'matriculas': estudiantes.map((e) => e['matricula']!).toList(),
            // Permite vincular al estudiante por correo si su matrícula no coincide.
            'correos': estudiantes
                .map((e) => (e['correo'] ?? '').toLowerCase())
                .where((c) => c.isNotEmpty)
                .toList(),
            'creadoEn': FieldValue.serverTimestamp(),
          }));

  // ─────────────────────────── SESIONES ───────────────────────────
  /// Id de la sesión abierta del curso (cierra las vencidas). null si no hay.
  static Future<String?> sesionAbierta(String cursoId) => _seguro(() async {
        final q = await _db
            .collection('sesiones')
            .where('cursoId', isEqualTo: cursoId)
            .where('estado', isEqualTo: 'abierta')
            .get();
        for (final d in q.docs) {
          final data = d.data();
          final ts = data['cierraEn']; // sesiones antiguas pueden no tenerlo
          final cierra = ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          if (data['pausada'] != true && DateTime.now().isAfter(cierra)) {
            await cerrarSesion(d.id);
          } else {
            return d.id;
          }
        }
        return null;
      });

  static Future<String> iniciarSesion({
    required String docenteUid,
    required String cursoId,
    required String cursoNombre,
    String aula = '',
    String edificio = '',
    required double lat,
    required double lng,
    required int radio,
    required int minutos,
    bool biometria = true,
    bool cierreEstricto = true,
  }) =>
      _seguro(() async {
        final codigo = (100000 + Random.secure().nextInt(900000)).toString();
        final ahora = DateTime.now();
        final ref = await _db.collection('sesiones').add({
          'docenteUid': docenteUid,
          'docenteNombre': FirebaseAuth.instance.currentUser?.displayName ?? '',
          'qrToken': _token(),
          'qrAnterior': '',
          'cursoId': cursoId,
          'cursoNombre': cursoNombre,
          'aula': aula,
          'edificio': edificio,
          'codigo': codigo,
          'lat': lat,
          'lng': lng,
          'radio': radio,
          'biometria': biometria,
          'cierreEstricto': cierreEstricto,
          'estado': 'abierta',
          'pausada': false,
          'expulsados': <String>[],
          'fueraRango': 0,
          'inicio': FieldValue.serverTimestamp(),
          'inicioLocal': Timestamp.fromDate(ahora),
          'cierraEn': Timestamp.fromDate(ahora.add(Duration(minutes: minutos))),
        });
        return ref.id;
      });

  static Future<void> pausar(String id) => _seguro(() => _db
      .collection('sesiones')
      .doc(id)
      .update({'pausada': true, 'pausadaEn': Timestamp.now()}));

  /// Al reanudar, el tiempo en pausa no se descuenta de la ventana.
  static Future<void> reanudar(String id) => _seguro(() async {
        final ref = _db.collection('sesiones').doc(id);
        final s = (await ref.get()).data();
        if (s == null || s['pausada'] != true) return;
        final p = (s['pausadaEn'] as Timestamp).toDate();
        final c = (s['cierraEn'] as Timestamp).toDate();
        await ref.update({
          'pausada': false,
          'pausadaEn': FieldValue.delete(),
          'cierraEn':
              Timestamp.fromDate(c.add(DateTime.now().difference(p))),
        });
      });

  static Future<void> extender(String id, int minutos) => _seguro(() async {
        final ref = _db.collection('sesiones').doc(id);
        final s = (await ref.get()).data();
        if (s == null) return;
        final c = (s['cierraEn'] as Timestamp).toDate();
        await ref.update(
            {'cierraEn': Timestamp.fromDate(c.add(Duration(minutes: minutos)))});
      });

  /// Cierra la sesión y guarda el acta: quien no marcó queda con falta.
  static Future<void> cerrarSesion(String id) => _seguro(() async {
        final ref = _db.collection('sesiones').doc(id);
        final s = (await ref.get()).data();
        if (s == null) return;
        if (s['estado'] != 'cerrada') {
          await ref.update({
            'estado': 'cerrada',
            'pausada': false,
            'cerradaEn': FieldValue.serverTimestamp(),
          });
        }
        await _generarFaltas(ref, s);
      });

  static Future<void> _generarFaltas(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> s) async {
    final cursoId = s['cursoId'] as String?;
    if (cursoId == null) return;
    final c = (await _db.collection('cursos').doc(cursoId).get()).data();
    final roster = ((c?['estudiantes'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (roster.isEmpty) return;
    final asist = await ref.collection('asistencias').get();
    final marcaron =
        asist.docs.map((d) => (d.data()['matricula'] ?? '').toString()).toSet();
    final batch = _db.batch();
    for (final e in roster) {
      final m = (e['matricula'] ?? '').toString();
      if (m.isEmpty || marcaron.contains(m)) continue;
      batch.set(ref.collection('asistencias').doc('m_$m'), {
        'nombre': e['nombre'] ?? 'Sin nombre',
        'matricula': m,
        'estado': 'falta',
        'hora': null,
        'distancia': null,
        'automatica': true,
      });
    }
    await batch.commit();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> sesion(String id) =>
      _db.collection('sesiones').doc(id).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> sesionesAbiertasDe(
          String docenteUid) =>
      _db
          .collection('sesiones')
          .where('docenteUid', isEqualTo: docenteUid)
          .where('estado', isEqualTo: 'abierta')
          .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> asistentes(String id) =>
      _db.collection('sesiones').doc(id).collection('asistencias').snapshots();

  /// "Expulsar": anula el check-in y evita que el alumno vuelva a marcar.
  static Future<void> expulsar(String sesionId, String estudianteUid) =>
      _seguro(() async {
        final ref = _db.collection('sesiones').doc(sesionId);
        final batch = _db.batch();
        batch.delete(ref.collection('asistencias').doc(estudianteUid));
        batch.update(ref, {
          'expulsados': FieldValue.arrayUnion([estudianteUid])
        });
        await batch.commit();
      });

  // ─────────────────── RESUMEN POR CURSO (panel Estudiantes) ───────────────────
  static DateTime _fecha(Map<String, dynamic> s) {
    final t = (s['inicioLocal'] ?? s['inicio'] ?? s['cierraEn']) as Timestamp?;
    return t?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Une el padrón del curso con las actas de sus sesiones cerradas.
  static Future<Map<String, dynamic>> resumenCurso(String cursoId) =>
      _seguro(() async {
        final c = (await _db.collection('cursos').doc(cursoId).get()).data();
        final roster = ((c?['estudiantes'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final q = await _db
            .collection('sesiones')
            .where('cursoId', isEqualTo: cursoId)
            .get();
        final cerradas = q.docs
            .where((d) => d.data()['estado'] == 'cerrada')
            .toList()
          ..sort((a, b) => _fecha(a.data()).compareTo(_fecha(b.data())));

        final est = <String, Map<String, dynamic>>{};
        Map<String, dynamic> nuevo(String m, String n, String correo) => {
              'matricula': m,
              'nombre': n,
              'correo': correo,
              'presentes': 0,
              'tardanzas': 0,
              'faltas': 0,
              'justificadas': 0,
              'ultimo': null,
              'historial': <Map<String, dynamic>>[],
            };
        for (final e in roster) {
          final m = (e['matricula'] ?? '').toString();
          est[m] = nuevo(m, (e['nombre'] ?? 'Sin nombre').toString(),
              (e['correo'] ?? '').toString());
        }

        for (var i = 0; i < cerradas.length; i++) {
          final sesion = cerradas[i];
          final asist = await sesion.reference.collection('asistencias').get();
          for (final doc in asist.docs) {
            final d = doc.data();
            final m = (d['matricula'] ?? doc.id).toString();
            final item = est.putIfAbsent(
                m, () => nuevo(m, (d['nombre'] ?? 'Sin nombre').toString(), ''));
            final estado = (d['estado'] ?? 'presente').toString();
            switch (estado) {
              case 'falta':
                item['faltas'] = (item['faltas'] as int) + 1;
              case 'justificada':
                item['justificadas'] = (item['justificadas'] as int) + 1;
              case 'tardanza':
                item['tardanzas'] = (item['tardanzas'] as int) + 1;
              default:
                item['presentes'] = (item['presentes'] as int) + 1;
            }
            final hora = (d['hora'] as Timestamp?)?.toDate();
            if (hora != null) item['ultimo'] = hora;
            (item['historial'] as List).add({
              'sesion': i + 1,
              'fecha': _fecha(sesion.data()),
              'estado': estado,
              'hora': hora,
              'distancia': d['distancia'],
              'motivo': d['motivo'],
              'sesionId': sesion.id,
              'docId': doc.id,
            });
          }
        }

        final total = cerradas.length;
        final cd = c ?? <String, dynamic>{};
        final maxF = maxFaltasDe(cd, total);
        final lista = est.values.toList();
        for (final e in lista) {
          final asistidas = (e['presentes'] as int) +
              (e['tardanzas'] as int) +
              (e['justificadas'] as int);
          e['porcentaje'] = total == 0 ? 100.0 : asistidas * 100 / total;
          e['maxFaltas'] = maxF;
          e['totalSesiones'] = totalSesionesBase(cd, total);
        }
        lista.sort((a, b) =>
            (a['nombre'] as String).compareTo(b['nombre'] as String));
        return {
          'cursoNombre': c?['nombre'] ?? 'Curso',
          'total': total,
          'maxFaltas': maxF,
          'sesionesPlanificadas': sesionesPlanificadas(cd),
          'totalSesiones': totalSesionesBase(cd, total),
          'estudiantes': lista,
        };
      });

  // ─────────────────────── QR DINÁMICO ───────────────────────
  static String _token() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => c[r.nextInt(c.length)]).join();
  }

  /// Genera un nuevo token de QR (cada 60 s). El anterior solo vale 15 s más,
  /// para no perder a quien está escaneando justo en el cambio.
  static Future<void> rotarQr(String id) => _seguro(() async {
        final ref = _db.collection('sesiones').doc(id);
        final s = (await ref.get()).data();
        if (s == null || s['estado'] != 'abierta' || s['pausada'] == true) return;
        await ref.update({
          'qrAnterior': s['qrToken'] ?? '',
          'qrToken': _token(),
          'qrRotadoEn': Timestamp.now(),
        });
      });

  // ─────────────── SOLICITUDES DE JUSTIFICACIÓN (docente) ───────────────
  static Stream<QuerySnapshot<Map<String, dynamic>>> solicitudesPendientes(
          String docenteUid) =>
      _db
          .collection('solicitudes')
          .where('docenteUid', isEqualTo: docenteUid)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots();

  /// Aprueba o rechaza. Al aprobar, la inasistencia queda como "justificada".
  static Future<void> resolverSolicitud(String id, Map<String, dynamic> sol,
          {required bool aprobar}) =>
      _seguro(() async {
        final batch = _db.batch();
        batch.update(_db.collection('solicitudes').doc(id), {
          'estado': aprobar ? 'aprobada' : 'rechazada',
          'resueltaEn': FieldValue.serverTimestamp(),
        });
        if (aprobar) {
          final docId = '${sol['docId'] ?? 'm_${sol['matricula']}'}';
          batch.set(
            _db
                .collection('sesiones')
                .doc('${sol['sesionId']}')
                .collection('asistencias')
                .doc(docId),
            {
              'nombre': sol['nombre'],
              'matricula': sol['matricula'],
              'estado': 'justificada',
              'motivo': sol['motivo'],
              'justificadaEn': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      });

  // ─────────────── SOLICITUDES: HISTORIAL (docente) ───────────────
  /// Todas las justificaciones presentadas a un docente (cualquier estado).
  static Stream<QuerySnapshot<Map<String, dynamic>>> solicitudesDelDocente(
          String docenteUid) =>
      _db
          .collection('solicitudes')
          .where('docenteUid', isEqualTo: docenteUid)
          .snapshots();

  // ─────────────────── TOTAL DE SESIONES (20 %) ───────────────────
  /// Total de sesiones del curso en el semestre. Si al final solo se dictaron
  /// 28 de 30, se ajusta a 28 y las fallas se recalculan sobre 28.
  static Future<void> actualizarSesionesPlanificadas(String cursoId, int total) =>
      _seguro(() async {
        if (total < 1 || total > 200) {
          throw AuthException('Indica un total de sesiones entre 1 y 200.');
        }
        await _db.collection('cursos').doc(cursoId).update({'sesionesPlanificadas': total});
      });

  // ─────────────── CRUCE DE HORARIOS (docente / estudiante) ───────────────
  static bool _solapa(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (diasDeCurso(a).intersection(diasDeCurso(b)).isEmpty) return false;
    final ai = horaInicioDe(a), af = horaFinDe(a), bi = horaInicioDe(b), bf = horaFinDe(b);
    if (ai == null || af == null || bi == null || bf == null) return false;
    int m((int, int) h) => h.$1 * 60 + h.$2;
    return m(ai) < m(bf) && m(bi) < m(af);
  }

  static String _rangoDe(Map<String, dynamic> c) =>
      '${c['dias'] ?? ''} ${c['horaInicio'] ?? ''}-${c['horaFin'] ?? ''}';

  /// null si no hay cruce. Si lo hay, devuelve el mensaje para mostrar.
  /// Revisa (1) otros cursos del docente y (2) cursos activos de cada estudiante.
  static Future<String?> conflictoHorario({
    required String docenteUid,
    required List<String> dias,
    required String horaInicio,
    required String horaFin,
    String semestre = '',
    List<String> matriculas = const [],
    String? excluirCursoId,
  }) =>
      _seguro(() async {
        final nuevo = {'diasLista': dias, 'horaInicio': horaInicio, 'horaFin': horaFin};
        bool aplica(String id, Map<String, dynamic> c) =>
            id != excluirCursoId &&
            c['estado'] != 'borrador' &&
            (semestre.isEmpty || '${c['semestre'] ?? ''}'.isEmpty || c['semestre'] == semestre) &&
            _solapa(nuevo, c);

        final propios = await _db.collection('cursos').where('docenteUid', isEqualTo: docenteUid).get();
        for (final d in propios.docs) {
          if (aplica(d.id, d.data())) {
            return 'Ya tienes "${d.data()['nombre']}" (${_rangoDe(d.data())}) que se cruza con este horario.';
          }
        }
        for (var i = 0; i < matriculas.length; i += 30) {
          final lote = matriculas.sublist(i, min(i + 30, matriculas.length));
          final q = await _db.collection('cursos').where('matriculas', arrayContainsAny: lote).get();
          for (final d in q.docs) {
            if (!aplica(d.id, d.data())) continue;
            final comunes = ((d.data()['matriculas'] as List?) ?? const []).where(lote.contains).toList();
            return 'El estudiante ${comunes.isEmpty ? '' : comunes.first} ya tiene "${d.data()['nombre']}" '
                '(${_rangoDe(d.data())}) activo en ese horario.';
          }
        }
        return null;
      });

  // ─────────────── PADRÓN: alta / edición / baja manual ───────────────
  static final RegExp _formatoCorreoPadron = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Misma estructura del Excel: matrícula; nombre; correo (opcional).
  static Future<void> _guardarPadron(
          String cursoId, List<Map<String, dynamic>> lista) =>
      _db.collection('cursos').doc(cursoId).update({
        'estudiantes': lista,
        'alumnos': lista.length,
        'matriculas': lista.map((e) => '${e['matricula']}').toList(),
        'correos': lista
            .map((e) => '${e['correo'] ?? ''}'.toLowerCase())
            .where((c) => c.isNotEmpty)
            .toList(),
      });

  static String? _validarAlumno(String m, String n, String c) {
    if (m.isEmpty || n.isEmpty) return 'La matrícula y el nombre son obligatorios.';
    if (c.isNotEmpty && !_formatoCorreoPadron.hasMatch(c)) return 'El correo no es válido.';
    if (c.isNotEmpty && !esCorreoPermitido(c)) return mensajeCorreoInvalido;
    return null;
  }

  /// Agrega (o, con [matriculaOriginal], actualiza) un estudiante del padrón.
  static Future<void> guardarEstudiante(
    String cursoId, {
    required String matricula,
    required String nombre,
    String correo = '',
    String? matriculaOriginal,
  }) =>
      _seguro(() async {
        final m = matricula.trim(), n = nombre.trim(), c = correo.trim().toLowerCase();
        final error = _validarAlumno(m, n, c);
        if (error != null) throw AuthException(error);
        final cur = (await _db.collection('cursos').doc(cursoId).get()).data();
        if (cur == null) throw AuthException('No se encontró el curso.');
        final lista = ((cur['estudiantes'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final orig = matriculaOriginal ?? m;
        if (lista.any((e) => '${e['matricula']}' == m && '${e['matricula']}' != orig)) {
          throw AuthException('Ya existe un estudiante con la matrícula $m.');
        }
        final i = lista.indexWhere((e) => '${e['matricula']}' == orig);
        final alumno = {'matricula': m, 'nombre': n, 'correo': c};
        if (i >= 0) {
          lista[i] = alumno;
        } else {
          // Alta nueva: no debe cruzarse con otro curso activo del estudiante.
          final choque = await conflictoHorario(
            docenteUid: '${cur['docenteUid']}',
            dias: ((cur['diasLista'] as List?) ?? const []).cast<String>(),
            horaInicio: '${cur['horaInicio']}',
            horaFin: '${cur['horaFin']}',
            semestre: '${cur['semestre'] ?? ''}',
            matriculas: [m],
            excluirCursoId: cursoId,
          );
          if (choque != null) throw AuthException(choque);
          lista.add(alumno);
        }
        await _guardarPadron(cursoId, lista);
      });

  static Future<void> eliminarEstudiante(String cursoId, String matricula) =>
      _seguro(() async {
        final cur = (await _db.collection('cursos').doc(cursoId).get()).data();
        if (cur == null) return;
        final lista = ((cur['estudiantes'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => '${e['matricula']}' != matricula)
            .toList();
        await _guardarPadron(cursoId, lista);
      });

  // ─────────────────── AVISO PREVENTIVO ───────────────────
  /// Envía un aviso automático al estudiante (se ve en su panel). También deja
  /// un documento en `mail` para la extensión "Trigger Email" de Firebase, que
  /// lo manda al correo si la tienes instalada.
  static Future<void> enviarAvisoPreventivo({
    required String docenteUid,
    required String cursoId,
    required String cursoNombre,
    required Map<String, dynamic> estudiante,
    required int faltas,
    required int maxFaltas,
  }) =>
      _seguro(() async {
        final correo = '${estudiante['correo'] ?? ''}'.trim().toLowerCase();
        final nombre = '${estudiante['nombre'] ?? ''}';
        final restantes = maxFaltas - faltas;
        final mensaje = faltas > maxFaltas
            ? 'Hola $nombre: superaste el 20% de inasistencias en $cursoNombre ($faltas faltas). '
                'Comunícate con tu docente.'
            : 'Hola $nombre: llevas $faltas de $maxFaltas faltas permitidas en $cursoNombre. '
                '${restantes <= 0 ? 'Una falta más y perderás la asignatura por inasistencia.' : 'Te quedan $restantes antes de perder la asignatura por inasistencia.'}';
        final batch = _db.batch();
        batch.set(_db.collection('notificaciones').doc(), {
          'tipo': 'preventivo',
          'docenteUid': docenteUid,
          'cursoId': cursoId,
          'cursoNombre': cursoNombre,
          'matricula': '${estudiante['matricula'] ?? ''}',
          'correo': correo,
          'mensaje': mensaje,
          'creadoEn': FieldValue.serverTimestamp(),
        });
        if (correo.isNotEmpty) {
          batch.set(_db.collection('mail').doc(), {
            'to': [correo],
            'message': {
              'subject': 'Aviso preventivo de inasistencias - $cursoNombre',
              'text': mensaje,
            },
          });
        }
        await batch.commit();
      });

  // ──────────────────────── LADO ESTUDIANTE ────────────────────────
  /// Distancia (m) entre una posición y el punto de la sesión.
  static double distanciaA(Position pos, Map<String, dynamic> sesion) =>
      Geolocator.distanceBetween(pos.latitude, pos.longitude,
          (sesion['lat'] as num).toDouble(), (sesion['lng'] as num).toDouble());

  /// Valida código, padrón, geocerca y registra la asistencia.
  /// Si ya tienes la ubicación (pantalla de marcado) pásala en [posicion].
  /// Devuelve los datos del registro para mostrar el comprobante.
  static Future<Map<String, dynamic>> registrarAsistencia({
    required Map<String, dynamic> perfil,
    String? codigo, // código manual de 6 dígitos
    String? qr, // contenido del QR: KAMPUS|sesionId|token
    Position? posicion,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> doc;
    if (qr != null) {
      final partes = qr.split('|');
      if (partes.length != 3 || partes[0] != 'KAMPUS') {
        throw AsistenciaError('QR no reconocido por KampusCheck.', 'qr');
      }
      doc = await _seguro(() => _db.collection('sesiones').doc(partes[1]).get());
      final d = doc.data();
      if (d == null || d['estado'] != 'abierta') {
        throw AsistenciaError('La sesión de este QR ya cerró.', 'qr');
      }
      final rot = (d['qrRotadoEn'] as Timestamp?)?.toDate();
      final gracia = rot != null && DateTime.now().difference(rot).inSeconds <= 15;
      if (d['qrToken'] != partes[2] && !(gracia && d['qrAnterior'] == partes[2])) {
        throw AsistenciaError(
            'El código QR caducó. Escanea el QR que se muestra ahora.', 'qr');
      }
    } else {
      final q = await _seguro(() => _db
          .collection('sesiones')
          .where('codigo', isEqualTo: (codigo ?? '').trim())
          .where('estado', isEqualTo: 'abierta')
          .limit(1)
          .get());
      if (q.docs.isEmpty) {
        throw AsistenciaError('Código inválido o la sesión ya cerró.', 'codigo');
      }
      doc = q.docs.first;
    }
    final s = doc.data()!;
    final uid = perfil['uid'] as String;
    final matricula = (perfil['matricula'] ?? '').toString().trim();

    if (s['pausada'] == true) {
      throw AsistenciaError(
          'El docente pausó el registro. Espera un momento.', 'pausada');
    }
    if (DateTime.now().isAfter((s['cierraEn'] as Timestamp).toDate())) {
      throw AsistenciaError('La sesión de asistencia ya terminó.', 'cerrada');
    }
    if (((s['expulsados'] as List?) ?? const []).contains(uid)) {
      throw AsistenciaError(
          'El docente anuló tu registro en esta sesión.', 'expulsado');
    }

    final curso = await AsistenciaProvider.curso(s['cursoId'] as String);
    final padron = ((curso?['matriculas'] as List?) ?? const []).cast<String>();
    final correo = (perfil['correo'] ?? '').toString().trim().toLowerCase();
    var matriculaCurso = matricula; // la que figura en el padrón del curso
    if (padron.isNotEmpty && !padron.contains(matricula)) {
      final roster = ((curso?['estudiantes'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map));
      final porCorreo = correo.isEmpty
          ? null
          : roster.where((e) => '${e['correo']}'.toLowerCase() == correo).firstOrNull;
      if (porCorreo == null) {
        throw AsistenciaError('No figuras en el padrón de este curso.', 'padron');
      }
      matriculaCurso = '${porCorreo['matricula']}';
    }

    // Un teléfono = un estudiante por clase: si este dispositivo ya registró
    // asistencia con otra cuenta, se bloquea (evita marcar por un compañero).
    final dispositivo = await idDispositivo();
    final dRef = doc.reference.collection('dispositivos').doc(dispositivo);
    final dSnap = await _seguro(() => dRef.get());
    if (dSnap.exists && dSnap.data()?['uid'] != uid) {
      throw AsistenciaError(
          'Este dispositivo ya registró la asistencia de otra cuenta en esta clase. '
          'Cada estudiante debe marcar desde su propio teléfono.',
          'dispositivo');
    }

    final previo = await _seguro(
        () => doc.reference.collection('asistencias').doc(uid).get());
    if (previo.exists) {
      throw AsistenciaError('Ya registraste tu asistencia.', 'duplicada');
    }

    Position pos;
    try {
      pos = posicion ?? await obtenerUbicacion();
    } on AsistenciaError {
      rethrow;
    } on AuthException catch (e) {
      throw AsistenciaError(e.mensaje, 'gps');
    }
    if (pos.isMocked) {
      throw AsistenciaError('Se detectó una ubicación simulada.', 'mock');
    }
    final dist = distanciaA(pos, s);
    final radio = (s['radio'] as num).toInt();
    final margen = min(pos.accuracy, 25.0); // tolerancia por precisión del GPS
    if (dist > radio + margen) {
      try {
        await doc.reference.update({'fueraRango': FieldValue.increment(1)});
      } catch (_) {}
      throw AsistenciaError(
          'Estás a ${dist.round()} m del aula. Debes estar dentro de $radio m.',
          'distancia',
          distancia: dist.round(),
          radio: radio);
    }

    final inicio = (s['inicioLocal'] as Timestamp?)?.toDate();
    final tarde = inicio != null &&
        DateTime.now().difference(inicio).inMinutes >= minutosTardanza;
    final estado = tarde ? 'tardanza' : 'presente';

    await _seguro(() {
      final batch = _db.batch();
      batch.set(doc.reference.collection('asistencias').doc(uid), {
        'nombre': perfil['nombre'],
        'matricula': matriculaCurso,
        'estado': estado,
        'hora': FieldValue.serverTimestamp(),
        'distancia': dist.round(),
        'dispositivo': dispositivo,
      });
      batch.set(dRef, {
        'uid': uid,
        'matricula': matriculaCurso,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      return batch.commit();
    });
    return {
      'sesionId': doc.id,
      'cursoNombre': s['cursoNombre'],
      'aula': s['aula'],
      'edificio': s['edificio'],
      'grupo': curso?['grupo'],
      'docenteNombre': curso?['docenteNombre'],
      'distancia': dist.round(),
      'radio': radio,
      'estado': estado,
      'hora': DateTime.now(),
    };
  }
}