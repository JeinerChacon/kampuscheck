import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Error con mensaje listo para mostrar en pantalla.
class AuthException implements Exception {
  final String mensaje;
  AuthException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Maneja login, registro y recuperación contra Firebase.
/// Perfil del usuario en Firestore: colección "usuarios", documento = UID.
class AuthProvider {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ───────────────────────── LOGIN ─────────────────────────
  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String password,
    required String rolEsperado, // 'estudiante' | 'docente' | 'soporte'
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        throw AuthException(
            'Tu cuenta no tiene un perfil registrado. Contacta a la Mesa de Ayuda.');
      }

      final perfil = doc.data()!;
      if (perfil['activo'] == false) {
        await _auth.signOut();
        throw AuthException('Tu cuenta está desactivada. Contacta a la Mesa de Ayuda.');
      }
      if (perfil['rol'] != rolEsperado) {
        await _auth.signOut();
        throw AuthException(perfil['rol'] == 'soporte'
            ? 'Esta cuenta es de Soporte. Entra desde los tres puntos (⋮) junto a "Docente".'
            : 'Esta cuenta pertenece a un ${perfil['rol']}. Cambia de rol e intenta de nuevo.');
      }

      return {...perfil, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    } on FirebaseException catch (e) {
      // Ej.: permission-denied (reglas) o Firestore sin crear
      await _auth.signOut();
      throw AuthException('No se pudo leer tu perfil (${e.code}).');
    }
  }

  // ──────────────────────── REGISTRO ────────────────────────
  /// [codigo] = matrícula (estudiante) o código de empleado (docente). Soporte no los usa.
  /// [programa] = carrera (estudiante) o departamento (docente).
  static Future<Map<String, dynamic>> registrar({
    required String rol,
    required String nombre,
    required String correo,
    required String password,
    String codigo = '',
    String programa = '',
  }) async {
    UserCredential? cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final perfil = <String, dynamic>{
        'rol': rol,
        'nombre': nombre.trim(),
        'correo': correo.trim(),
        'activo': true,
        if (rol == 'soporte') ...{
          // registro breve: sin matrícula ni departamento
        } else if (rol == 'estudiante') ...{
          'matricula': codigo.trim(),
          'carrera': programa,
        } else ...{
          'codigoEmpleado': codigo.trim(),
          'departamento': programa,
        },
      };

      await _db.collection('usuarios').doc(uid).set({
        ...perfil,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      await cred.user!.updateDisplayName(nombre.trim());

      return {...perfil, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    } on FirebaseException catch (e) {
      // Si falló guardar el perfil, borramos la cuenta para no dejarla a medias
      await cred?.user?.delete();
      throw AuthException('No se pudo guardar tu perfil (${e.code}).');
    }
  }

  // ─────────────────────── RECUPERACIÓN ───────────────────────
  static Future<void> enviarRecuperacion(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  // ───────────────────────── SESIÓN ─────────────────────────
  /// Perfil del usuario con sesión abierta (null si no hay sesión o perfil válido).
  static Future<Map<String, dynamic>?> perfilActual() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists || doc.data()!['activo'] == false) {
        await _auth.signOut();
        return null;
      }
      return {...doc.data()!, 'uid': user.uid};
    } on FirebaseException {
      return null; // sin conexión / reglas: no cerramos la sesión, solo no entramos
    }
  }

  static Future<void> cerrarSesion() => _auth.signOut();

  static User? get usuarioActual => _auth.currentUser;

  // ──────────────── Mensajes de error en español ────────────────
  static String _traducir(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Contraseña o correo no coinciden, por favor intenta de nuevo.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada. Contacta a la Mesa de Ayuda.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 8 caracteres).';
      case 'operation-not-allowed':
        return 'El login por correo no está activado en Firebase (Authentication).';
      default:
        return 'Error de autenticación ($code).';
    }
  }
}