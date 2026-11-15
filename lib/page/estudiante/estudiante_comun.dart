import 'package:flutter/material.dart';
import '../../src/app_theme.dart';
import '../../src/horario.dart';
import '../../src/kampus_widgets.dart';

/// Utilidades compartidas por las pestañas del estudiante.
const kAmbar = Color(0xFFF5B942);
const diasLargo = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const diasCorto = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String ampm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

String etiquetaDia(DateTime d, DateTime ahora) {
  final dif = soloDia(d).difference(soloDia(ahora)).inDays;
  if (dif == 0) return 'Hoy';
  if (dif == 1) return 'Mañana';
  return diasCorto[d.weekday - 1];
}

String enTiempo(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return 'En ${m < 1 ? 1 : m} min';
  return 'En ${(m / 60).round()} hrs';
}

String duracion(DateTime a, DateTime b) {
  final m = b.difference(a).inMinutes;
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '${r}m';
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

String fechaLarga(DateTime d) => '${diasLargo[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]}';

Widget chipEstado(String t, Color c, {IconData? icono}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icono != null) ...[Icon(icono, size: 13, color: c), const SizedBox(width: 4)],
        Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
      ]),
    );

typedef Clase = ({Map<String, dynamic> curso, DateTime ini, DateTime fin});

/// Clases de un día concreto, ordenadas por hora.
List<Clase> clasesDelDia(List<Map<String, dynamic>> cursos, DateTime dia) {
  final r = <Clase>[];
  for (final c in cursos) {
    final i = horaInicioDe(c);
    final f = horaFinDe(c);
    if (i == null || f == null || !diasDeCurso(c).contains(dia.weekday)) continue;
    r.add((
      curso: c,
      ini: DateTime(dia.year, dia.month, dia.day, i.$1, i.$2),
      fin: DateTime(dia.year, dia.month, dia.day, f.$1, f.$2),
    ));
  }
  r.sort((a, b) => a.ini.compareTo(b.ini));
  return r;
}

/// Carga los datos compartidos del estudiante y muestra espera / error / contenido
/// (con "deslizar para recargar").
class EstudianteFuturo extends StatelessWidget {
  final Future<Map<String, dynamic>> datos;
  final Future<void> Function() onRecargar;
  final List<Widget> Function(Map<String, dynamic> d) construir;
  const EstudianteFuturo({super.key, required this.datos, required this.onRecargar, required this.construir});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: datos,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.verde));
        }
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            const InfoBox(icono: Icons.error_outline, color: AppColors.rojo, texto: 'No se pudieron cargar tus cursos. Revisa tu conexión y las reglas de Firestore.'),
            const SizedBox(height: 12),
            PrimaryButton(texto: 'Reintentar', icono: Icons.refresh, onPressed: onRecargar),
          ]);
        }
        return RefreshIndicator(
          color: AppColors.verde,
          onRefresh: onRecargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: construir(snap.data!),
          ),
        );
      },
    );
  }
}

/// Diálogo para escribir un motivo (el controller vive dentro del diálogo).
Future<String?> pedirMotivo(BuildContext context, {required String titulo, String ayuda = 'Motivo'}) =>
    showDialog<String>(context: context, builder: (_) => _DialogMotivo(titulo: titulo, ayuda: ayuda));

class _DialogMotivo extends StatefulWidget {
  final String titulo;
  final String ayuda;
  const _DialogMotivo({required this.titulo, required this.ayuda});

  @override
  State<_DialogMotivo> createState() => _DialogMotivoState();
}

class _DialogMotivoState extends State<_DialogMotivo> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: Text(widget.titulo),
        content: TextField(
          controller: _c,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.ayuda, errorText: _error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (_c.text.trim().length < 5) {
                setState(() => _error = 'Cuéntale al docente qué pasó (mínimo 5 letras).');
                return;
              }
              Navigator.pop(context, _c.text.trim());
            },
            child: const Text('Enviar'),
          ),
        ],
      );
}