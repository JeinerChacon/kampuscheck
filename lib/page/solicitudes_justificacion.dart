import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../providers/asistencia_provider.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import 'estudiante/historial_justificaciones_page.dart';

/// Solicitudes de justificación enviadas por los estudiantes (pendientes).
/// Se muestra en "Estudiantes" y en la clase en vivo. Si no hay ninguna, no ocupa espacio.
class SolicitudesJustificacion extends StatelessWidget {
  final String docenteUid;
  final String? cursoId; // si se indica, solo las de ese curso
  const SolicitudesJustificacion({super.key, required this.docenteUid, this.cursoId});

  Future<void> _resolver(BuildContext context, String id, Map<String, dynamic> sol, bool aprobar) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      await AsistenciaProvider.resolverSolicitud(id, sol, aprobar: aprobar);
      msg.showSnackBar(SnackBar(content: Text(aprobar ? 'Justificación aprobada.' : 'Solicitud rechazada.')));
    } on AuthException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  static String _fechaClase(Object? t) {
    if (t is! Timestamp) return 'fecha no registrada';
    final d = t.toDate();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(d.day)}/${dd(d.month)}/${d.year} ${dd(d.hour)}:${dd(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AsistenciaProvider.solicitudesPendientes(docenteUid),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? [])
            .where((d) => cursoId == null || d.data()['cursoId'] == cursoId)
            .toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: KampusCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.mark_email_unread_outlined, color: Color(0xFFF5B942), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Solicitudes de justificación (${docs.length})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 10),
              for (final d in docs)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d.data()['nombre']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('ID ${d.data()['matricula']} • ${d.data()['cursoNombre']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                    Text('Clase: ${_fechaClase(d.data()['sesionFecha'])}',
                        style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                    const SizedBox(height: 6),
                    Text('${d.data()['motivo']}', style: const TextStyle(fontSize: 13)),
                    if ('${d.data()['adjuntoB64'] ?? ''}'.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => descargarAdjunto(context, d.data()),
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text('${d.data()['adjuntoNombre'] ?? 'Adjunto'}', overflow: TextOverflow.ellipsis),
                      ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: () => _resolver(context, d.id, d.data(), false),
                        child: const Text('Rechazar', style: TextStyle(color: AppColors.rojo)),
                      ),
                      TextButton(
                        onPressed: () => _resolver(context, d.id, d.data(), true),
                        child: const Text('Aprobar'),
                      ),
                    ]),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }
}