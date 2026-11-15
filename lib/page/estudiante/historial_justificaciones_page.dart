import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/asistencia_provider.dart';
import '../../providers/estudiante_provider.dart';
import '../../src/app_theme.dart';
import '../../src/archivos.dart';
import '../../src/kampus_widgets.dart';

/// Registro (historial) de justificaciones presentadas.
/// - Docente: pasa [docenteUid] y ve las de todos sus estudiantes.
/// - Estudiante: pasa [uid] y ve solo las suyas.
class HistorialJustificacionesPage extends StatefulWidget {
  final String? docenteUid;
  final String? uid;
  const HistorialJustificacionesPage({super.key, this.docenteUid, this.uid});

  @override
  State<HistorialJustificacionesPage> createState() => _HistorialJustificacionesPageState();
}

class _HistorialJustificacionesPageState extends State<HistorialJustificacionesPage> {
  String _filtro = 'Todas';

  String _fecha(Object? t) {
    if (t is! Timestamp) return '--';
    final d = t.toDate();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(d.day)}/${dd(d.month)}/${d.year} ${dd(d.hour)}:${dd(d.minute)}';
  }

  (String, Color) _estado(String e) => switch (e) {
        'aprobada' => ('Aprobada', AppColors.verde),
        'rechazada' => ('Rechazada', AppColors.rojo),
        _ => ('Pendiente', const Color(0xFFF5B942)),
      };

  @override
  Widget build(BuildContext context) {
    final esDocente = widget.docenteUid != null;
    final stream = esDocente
        ? AsistenciaProvider.solicitudesDelDocente(widget.docenteUid!)
        : EstudianteProvider.misSolicitudes(widget.uid ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de justificaciones')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.verde));
            }
            final docs = snap.data!.docs.toList()
              ..sort((a, b) {
                final x = (a.data()['creadoEn'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final y = (b.data()['creadoEn'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return y.compareTo(x);
              });
            final visibles = docs.where((d) {
              final e = '${d.data()['estado']}';
              return switch (_filtro) {
                'Pendientes' => e == 'pendiente',
                'Aprobadas' => e == 'aprobada',
                'Rechazadas' => e == 'rechazada',
                _ => true,
              };
            }).toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 8, children: [
                for (final f in ['Todas', 'Pendientes', 'Aprobadas', 'Rechazadas'])
                  ChoiceChip(
                    label: Text(f),
                    selected: _filtro == f,
                    onSelected: (_) => setState(() => _filtro = f),
                  ),
              ]),
              const SizedBox(height: 12),
              if (visibles.isEmpty)
                const InfoBox(icono: Icons.history_edu_outlined, texto: 'Aún no hay justificaciones en este filtro.'),
              for (final d in visibles) _tarjeta(d.data(), esDocente),
            ]);
          },
        ),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> s, bool esDocente) {
    final (txt, color) = _estado('${s['estado']}');
    final adj = '${s['adjuntoB64'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              esDocente ? '${s['nombre']} • ${s['matricula']}' : '${s['cursoNombre']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
            child: Text(txt, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        if (esDocente) Text('${s['cursoNombre']}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        Text('Clase del ${_fecha(s['sesionFecha'])}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        Text('Presentada el ${_fecha(s['creadoEn'])}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
        const SizedBox(height: 8),
        Text('${s['motivo']}', style: const TextStyle(fontSize: 13)),
        if (adj.isNotEmpty)
          TextButton.icon(
            onPressed: () => descargarAdjunto(context, s),
            icon: const Icon(Icons.attach_file, size: 16),
            label: Text('${s['adjuntoNombre'] ?? 'Adjunto'}', overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }
}

/// Guarda el archivo adjunto de una justificación en el dispositivo.
Future<void> descargarAdjunto(BuildContext context, Map<String, dynamic> s) async {
  final msg = ScaffoldMessenger.of(context);
  try {
    final ok = await guardarArchivoBytes('${s['adjuntoNombre'] ?? 'adjunto'}', base64Decode('${s['adjuntoB64']}'));
    if (ok) msg.showSnackBar(const SnackBar(content: Text('Archivo guardado.')));
  } catch (_) {
    msg.showSnackBar(const SnackBar(content: Text('No se pudo guardar el archivo.')));
  }
}