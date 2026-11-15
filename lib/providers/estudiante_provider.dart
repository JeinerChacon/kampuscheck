import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../src/inasistencias.dart';
import 'auth_provider.dart';

/// Datos del lado estudiante: cursos donde está matriculado y su control de faltas.
///
/// El vínculo estudiante ↔ curso se hace con el padrón que cargó el docente:
///  - por matrícula  -> campo `matriculas` del curso
///  - por correo     -> campo `correos` del curso
/// (si coincide cualquiera de los dos, el curso aparece en su panel).
class EstudianteProvider {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Asistencia mínima requerida (%).
  static const double asistenciaMinima = 80;

  static Future<List<Map<String, dynamic>>> cursosDe({
    required String matricula,
    required String correo,
  }) async {
    final col = _db.collection('cursos');
    final consultas = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      if (matricula.isNotEmpty) col.where('matriculas', arrayContains: matricula).get(),
      if (correo.isNotEmpty) col.where('correos', arrayContains: correo).get(),
    ];
    final resultados = await Future.wait(consultas);
    final porId = <String, Map<String, dynamic>>{};
    for (final r in resultados) {
      for (final d in r.docs) {
        if (d.data()['estado'] == 'borrador') continue;
        porId[d.id] = {...d.data(), 'id': d.id};
      }
    }
    return porId.values.toList();
  }

  /// Matrícula con la que el estudiante figura en el padrón de ese curso
  /// (puede diferir de la de su perfil si lo vincularon por correo).
  static String _matriculaEnCurso(
      Map<String, dynamic> curso, String matricula, String correo) {
    final roster = (curso['estudiantes'] as List?) ?? const [];
    for (final e in roster) {
      final m = Map<String, dynamic>.from(e as Map);
      if (matricula.isNotEmpty && '${m['matricula']}' == matricula) return matricula;
      if (correo.isNotEmpty && '${m['correo']}'.toLowerCase() == correo) {
        return '${m['matricula']}';
      }
    }
    return matricula;
  }

  static Future<Map<String, dynamic>?> _asistenciaDe(
      DocumentReference<Map<String, dynamic>> sesion, String uid, String matricula) async {
    final coleccion = sesion.collection('asistencias');
    if (matricula.isNotEmpty) {
      final q = await coleccion.where('matricula', isEqualTo: matricula).limit(1).get();
      if (q.docs.isNotEmpty) {
        return {...q.docs.first.data(), '_id': q.docs.first.id};
      }
    }
    final d = await coleccion.doc(uid).get();
    final dd = d.data();
    return dd == null ? null : {...dd, '_id': d.id};
  }

  static Future<Map<String, dynamic>> _detalle(Map<String, dynamic> c, String uid,
      String matricula, String correo) async {
    final mat = _matriculaEnCurso(c, matricula, correo);
    final q = await _db.collection('sesiones').where('cursoId', isEqualTo: c['id']).get();
    final ahora = DateTime.now();

    var dictadas = 0, presentes = 0, tardanzas = 0, faltas = 0, justificadas = 0;
    String? abierta;
    Map<String, dynamic>? miRegistro;
    final pendientes = <Future<void>>[];
    final historial = <Map<String, dynamic>>[];

    for (final s in q.docs) {
      final d = s.data();
      final estado = d['estado'];
      if (estado == 'abierta') {
        final cierra = (d['cierraEn'] as Timestamp?)?.toDate();
        final vigente = d['pausada'] == true || (cierra != null && cierra.isAfter(ahora));
        if (!vigente) continue; // quedó abierta pero ya venció: no cuenta
        abierta = s.id;
        pendientes.add(() async {
          final a = await _asistenciaDe(s.reference, uid, mat);
          if (a != null) miRegistro = a;
        }());
      } else if (estado == 'cerrada') {
        dictadas++;
        pendientes.add(() async {
          final a = await _asistenciaDe(s.reference, uid, mat);
          final e = '${a?['estado'] ?? 'falta'}';
          historial.add({
            'sesionId': s.id,
            'docId': a?['_id'],
            'estado': e,
            'fecha': (d['inicioLocal'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
          switch (e) {
            case 'falta':
              faltas++;
            case 'justificada':
              justificadas++;
            case 'tardanza':
              tardanzas++;
            default:
              presentes++;
          }
        }());
      }
    }
    await Future.wait(pendientes);

    return {
      ...c,
      'dictadas': dictadas,
      'presentes': presentes,
      'tardanzas': tardanzas,
      'faltas': faltas,
      'justificadas': justificadas,
      'porcentaje': dictadas == 0 ? 100.0 : (dictadas - faltas) * 100 / dictadas,
      'totalSesiones': totalSesionesBase(c, dictadas),
      'maxFaltas': maxFaltasDe(c, dictadas),
      'historial': historial..sort((x, y) => (x['fecha'] as DateTime).compareTo(y['fecha'] as DateTime)),
      'sesionAbierta': abierta,
      'miRegistro': miRegistro,
    };
  }

  /// Tamaño máximo del adjunto (se guarda dentro del documento de Firestore).
  static const int maxAdjuntoBytes = 700 * 1024;

  /// Envía al docente una solicitud de justificación de UNA inasistencia
  /// concreta (sesión = clase de una fecha y hora). Puede llevar archivo.
  /// [docId] = registro de falta existente (null si nunca llegó a registrarse).
  static Future<void> enviarSolicitud({
    required Map<String, dynamic> perfil,
    required String sesionId,
    String? docId,
    required String motivo,
    String? adjuntoNombre,
    Uint8List? adjunto,
  }) async {
    try {
      if (adjunto != null && adjunto.length > maxAdjuntoBytes) {
        throw AuthException('El archivo supera 700 KB. Comprime la imagen o el PDF.');
      }
      final s = (await _db.collection('sesiones').doc(sesionId).get()).data();
      if (s == null) throw AuthException('No se encontró la sesión.');
      final previa = await _db
          .collection('solicitudes')
          .where('uid', isEqualTo: perfil['uid'])
          .where('sesionId', isEqualTo: sesionId)
          .get();
      if (previa.docs.any((d) => d.data()['estado'] != 'rechazada')) {
        throw AuthException('Ya enviaste una justificación para esta clase.');
      }
      final curso =
          (await _db.collection('cursos').doc('${s['cursoId']}').get()).data() ?? {};
      final matricula = '${perfil['matricula'] ?? ''}'.trim();
      final correo = '${perfil['correo'] ?? ''}'.trim().toLowerCase();
      await _db.collection('solicitudes').add({
        'docenteUid': s['docenteUid'],
        'cursoId': s['cursoId'],
        'cursoNombre': s['cursoNombre'],
        'sesionId': sesionId,
        'sesionFecha': s['inicioLocal'],
        'docId': docId,
        'uid': perfil['uid'],
        'nombre': perfil['nombre'],
        'matricula': _matriculaEnCurso(curso, matricula, correo),
        'motivo': motivo.trim(),
        if (adjunto != null) ...{
          'adjuntoNombre': adjuntoNombre ?? 'adjunto',
          'adjuntoB64': base64Encode(adjunto),
        },
        'estado': 'pendiente',
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthException('No se pudo enviar la solicitud (${e.code}).');
    }
  }

  /// Historial de justificaciones del propio estudiante.
  static Stream<QuerySnapshot<Map<String, dynamic>>> misSolicitudes(String uid) =>
      _db.collection('solicitudes').where('uid', isEqualTo: uid).snapshots();

  /// Avisos preventivos enviados por docentes (por correo o matrícula).
  static Stream<QuerySnapshot<Map<String, dynamic>>> avisos(
          String correo, String matricula) =>
      _db
          .collection('notificaciones')
          .where(Filter.or(
            Filter('correo', isEqualTo: correo),
            Filter('matricula', isEqualTo: matricula),
          ))
          .snapshots();

  /// Todo lo que necesita el dashboard del estudiante.
  static Future<Map<String, dynamic>> cargar(Map<String, dynamic> perfil) async {
    final uid = perfil['uid'] as String;
    final matricula = '${perfil['matricula'] ?? ''}'.trim();
    final correo = '${perfil['correo'] ?? ''}'.trim().toLowerCase();

    final cursos = await cursosDe(matricula: matricula, correo: correo);
    final detallados = await Future.wait(cursos.map((c) => _detalle(c, uid, matricula, correo)));

    var dictadas = 0, faltas = 0, justificadas = 0;
    for (final c in detallados) {
      dictadas += c['dictadas'] as int;
      faltas += c['faltas'] as int;
      justificadas += c['justificadas'] as int;
    }
    return {
      'cursos': detallados,
      'dictadas': dictadas,
      'faltas': faltas,
      'justificadas': justificadas,
      'porcentaje': dictadas == 0 ? 100.0 : (dictadas - faltas) * 100 / dictadas,
    };
  }
}