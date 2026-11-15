import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../providers/estudiante_provider.dart';
import '../../src/app_theme.dart';
import '../../src/kampus_widgets.dart';
import '../soporte/soporte_ayuda_page.dart';
import 'dialogo_justificacion.dart';
import 'estudiante_comun.dart';
import 'historial_justificaciones_page.dart';

/// Pestaña "Perfil": datos, seguridad, preferencias, justificaciones y cierre de sesión.
class EstudiantePerfil extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final Future<Map<String, dynamic>> datos;
  const EstudiantePerfil({super.key, required this.perfil, required this.datos});

  @override
  State<EstudiantePerfil> createState() => _EstudiantePerfilState();
}

class _EstudiantePerfilState extends State<EstudiantePerfil> {
  late bool _alertas = _pref('alertas');

  bool _pref(String k) {
    final m = widget.perfil['preferencias'];
    return m is Map ? (m[k] as bool? ?? true) : true;
  }

  void _aviso(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guardarPref(String k, bool v) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.perfil['uid'] as String)
          .set({'preferencias': {k: v}}, SetOptions(merge: true));
    } catch (_) {
      _aviso('No se pudo guardar la preferencia.');
    }
  }

  Future<void> _cambiarClave() async {
    final correo = '${widget.perfil['correo'] ?? ''}';
    try {
      await AuthProvider.enviarRecuperacion(correo);
      _aviso('Enviamos un enlace a $correo');
    } on AuthException catch (e) {
      _aviso(e.mensaje);
    }
  }

  void _dispositivos() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.tarjeta,
          title: const Text('Dispositivos autorizados'),
          content: const Text('Tu cuenta está activa en este dispositivo. La gestión de varios dispositivos estará disponible próximamente.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
        ),
      );

  /// Soporte: el estudiante elige una falta injustificada y pide justificarla.
  Future<void> _soporte() async {
    final d = await widget.datos;
    if (!mounted) return;
    final faltas = <({String curso, Map<String, dynamic> h})>[];
    for (final c in (d['cursos'] as List).cast<Map<String, dynamic>>()) {
      for (final h in (c['historial'] as List).cast<Map<String, dynamic>>()) {
        if (h['estado'] == 'falta') faltas.add((curso: '${c['nombre']}', h: h));
      }
    }
    if (faltas.isEmpty) {
      _aviso('No tienes faltas injustificadas por justificar.');
      return;
    }
    final r = await pedirJustificacion(
      context,
      detalle: 'La justificación aplica solo a la clase (fecha y hora) que elijas.',
      faltas: [
        for (final f in faltas)
          '${f.curso} • ${(f.h['fecha'] as DateTime).day} ${meses[(f.h['fecha'] as DateTime).month - 1]} ${hm(f.h['fecha'] as DateTime)}',
      ],
    );
    if (r == null || !mounted) return;
    final h = faltas[r.indice].h;
    try {
      await EstudianteProvider.enviarSolicitud(
        perfil: widget.perfil,
        sesionId: '${h['sesionId']}',
        docId: h['docId'] as String?,
        motivo: r.motivo,
        adjuntoNombre: r.archivoNombre,
        adjunto: r.archivo,
      );
      _aviso('Solicitud enviada a tu docente.');
    } on AuthException catch (e) {
      _aviso(e.mensaje);
    }
  }

  Widget _fila(IconData i, String titulo, String sub, {Widget? fin, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(12)),
              child: Icon(i, color: AppColors.verde),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.gris)),
              ]),
            ),
            if (fin != null) fin,
          ]),
        ),
      );

  Widget _seccion(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gris, letterSpacing: 1)),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;
    final nombre = '${p['nombre'] ?? 'Estudiante'}';
    final iniciales = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).take(2).map((x) => x[0].toUpperCase()).join();
    return ListView(padding: const EdgeInsets.all(16), children: [
      KampusCard(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.verde, width: 3)),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.campo,
              child: Text(iniciales, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.verde)),
            ),
          ),
          const SizedBox(height: 14),
          Text(nombre, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${p['carrera'] ?? '---'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.verde)),
          const SizedBox(height: 8),
          Text('ID: ${p['matricula'] ?? '---'}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          Text('${p['correo'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          const SizedBox(height: 12),
          chipEstado('Estudiante Regular Activo', AppColors.verde, icono: Icons.check_circle),
        ]),
      ),
      _seccion('SEGURIDAD DE LA CUENTA'),
      _fila(Icons.lock_reset, 'Cambiar Contraseña', 'Te enviaremos un enlace a tu correo', fin: const Icon(Icons.chevron_right, color: AppColors.gris), onTap: _cambiarClave),
      _fila(Icons.devices, 'Dispositivos Autorizados', 'Protección anti-suplantación', fin: chipEstado('1 móvil', AppColors.texto), onTap: _dispositivos),
      _seccion('PREFERENCIAS DEL SISTEMA'),
      _fila(
        Icons.notifications_none,
        'Alertas de Asistencia',
        'Preferencia guardada en tu cuenta',
        fin: Switch(
          value: _alertas,
          activeTrackColor: AppColors.verde,
          activeThumbColor: Colors.black,
          onChanged: (v) {
            setState(() => _alertas = v);
            _guardarPref('alertas', v);
          },
        ),
      ),
      _fila(Icons.dark_mode_outlined, 'Tema de Pantalla', 'Fondo azul noche • Activado', fin: chipEstado('Sistema', AppColors.gris)),
      const SizedBox(height: 10),
      for (final b in <(IconData, String, VoidCallback)>[
        (Icons.support_agent, 'Soporte Técnico (Mesa de Ayuda)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SoporteAyudaPage(perfil: p)))),
        (Icons.assignment_ind_outlined, 'Justificar Inasistencias', _soporte),
        (Icons.history_edu_outlined, 'Mis Justificaciones (registro)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistorialJustificacionesPage(uid: '${p['uid']}')))),
      ])
        GestureDetector(
          onTap: b.$3,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(b.$1, color: AppColors.verde, size: 20),
              const SizedBox(width: 8),
              Text(b.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => AuthProvider.cerrarSesion(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: const Color(0xFF8E1B1B), borderRadius: BorderRadius.circular(16)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 8),
            Text('Cerrar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      const Center(child: Text('KampusCheck • Terminal Estudiantil Segura', style: TextStyle(fontSize: 11, color: AppColors.gris))),
    ]);
  }
}