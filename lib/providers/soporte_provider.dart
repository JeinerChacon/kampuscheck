import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

/// Mesa de ayuda: tickets de chat entre usuarios y agentes de soporte.
///
/// tickets/{id}           -> uid, nombre, correo, rol, estado (abierto|cerrado),
///                           agenteUid, agenteNombre, ultimoMensaje, ultimoEn, creadoEn
/// tickets/{id}/mensajes  -> de, nombre, rol (usuario|soporte), texto, creadoEn
///
/// Un agente de soporte es un usuario con `rol: 'soporte'` en la colección
/// `usuarios` (se asigna a mano en la consola de Firebase).
class SoporteProvider {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String correo = 'soporte-asistencia@kampus.edu';

  static String numero(String ticketId) =>
      'TCK-${ticketId.substring(0, 4).toUpperCase()}';

  static Future<T> _seguro<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseException catch (e) {
      throw AuthException(e.code == 'permission-denied'
          ? 'Sin permisos en la mesa de ayuda. Revisa las reglas de Firestore para tickets (ver instrucciones).'
          : 'Error con la mesa de ayuda (${e.code}).');
    }
  }

  /// Id del ticket abierto del usuario (null si no tiene).
  static Future<String?> ticketAbiertoDe(String uid) => _seguro(() async {
        final q = await _db
            .collection('tickets')
            .where('uid', isEqualTo: uid)
            .where('estado', isEqualTo: 'abierto')
            .limit(1)
            .get();
        return q.docs.isEmpty ? null : q.docs.first.id;
      });

  static Stream<DocumentSnapshot<Map<String, dynamic>>> ticket(String id) =>
      _db.collection('tickets').doc(id).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> mensajes(String id) => _db
      .collection('tickets')
      .doc(id)
      .collection('mensajes')
      .orderBy('creadoEn')
      .snapshots();

  /// Lista de tickets para el agente.
  static Stream<QuerySnapshot<Map<String, dynamic>>> tickets({required bool abiertos}) =>
      _db
          .collection('tickets')
          .where('estado', isEqualTo: abiertos ? 'abierto' : 'cerrado')
          .snapshots();

  /// Ticket de alguien SIN sesión (no puede iniciar sesión). El agente lo ve
  /// en su panel con el correo de contacto y le responde por correo.
  static Future<void> enviarInvitado({
    required String nombre,
    required String correo,
    required String texto,
  }) =>
      _seguro(() async {
        final n = nombre.trim(), c = correo.trim().toLowerCase(), t = texto.trim();
        if (n.isEmpty) throw AuthException('Escribe tu nombre.');
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(c)) {
          throw AuthException('Escribe un correo válido para poder responderte.');
        }
        if (t.length < 5) throw AuthException('Cuéntanos brevemente qué pasa.');
        final tRef = _db.collection('tickets').doc();
        await tRef.set({
          'uid': 'invitado',
          'invitado': true,
          'nombre': n,
          'correo': c,
          'rol': 'sin sesión',
          'estado': 'abierto',
          'agenteUid': null,
          'agenteNombre': null,
          'ultimoMensaje': t,
          'ultimoEn': FieldValue.serverTimestamp(),
          'creadoEn': FieldValue.serverTimestamp(),
        });
        await tRef.collection('mensajes').doc().set({
          'de': 'invitado',
          'nombre': n,
          'rol': 'usuario',
          'texto': t,
          'creadoEn': FieldValue.serverTimestamp(),
        });
      });

  /// Envía un mensaje. Si el usuario no tiene ticket, lo crea.
  /// Devuelve el id del ticket.
  static Future<String> enviar({
    required Map<String, dynamic> perfil,
    String? ticketId,
    required String texto,
    bool comoSoporte = false,
  }) =>
      _seguro(() async {
        final t = texto.trim();
        if (t.isEmpty) throw AuthException('Escribe un mensaje.');
        final uid = perfil['uid'] as String;
        final tRef = ticketId == null
            ? _db.collection('tickets').doc()
            : _db.collection('tickets').doc(ticketId);
        final mRef = tRef.collection('mensajes').doc();

        if (ticketId == null) {
          // 1) Primero el ticket y luego el mensaje (en dos pasos): las reglas
          //    de "mensajes" consultan el ticket padre, que debe existir ya.
          await tRef.set({
            'uid': uid,
            'nombre': perfil['nombre'],
            'correo': perfil['correo'],
            'rol': perfil['rol'],
            'estado': 'abierto',
            'agenteUid': null,
            'agenteNombre': null,
            'ultimoMensaje': t,
            'ultimoEn': FieldValue.serverTimestamp(),
            'creadoEn': FieldValue.serverTimestamp(),
          });
          await mRef.set({
            'de': uid,
            'nombre': perfil['nombre'],
            'rol': 'usuario',
            'texto': t,
            'creadoEn': FieldValue.serverTimestamp(),
          });
        } else {
          await mRef.set({
            'de': uid,
            'nombre': perfil['nombre'],
            'rol': comoSoporte ? 'soporte' : 'usuario',
            'texto': t,
            'creadoEn': FieldValue.serverTimestamp(),
          });
          await tRef.update({
            'ultimoMensaje': t,
            'ultimoEn': FieldValue.serverTimestamp(),
            if (comoSoporte) ...{
              'agenteUid': uid,
              'agenteNombre': perfil['nombre'],
            },
          });
        }
        return tRef.id;
      });

  static Future<void> cerrar(String ticketId) => _seguro(() => _db
      .collection('tickets')
      .doc(ticketId)
      .update({'estado': 'cerrado', 'cerradoEn': FieldValue.serverTimestamp()}));
}