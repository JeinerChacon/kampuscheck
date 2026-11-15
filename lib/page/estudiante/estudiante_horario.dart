import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/asistencia_provider.dart';
import '../../src/app_theme.dart';
import '../../src/archivos.dart';
import '../../src/horario.dart';
import '../../src/kampus_widgets.dart';
import 'estudiante_comun.dart';

/// Pestaña "Horario": agenda por día y vista semanal, con exportación del horario.
class EstudianteHorario extends StatefulWidget {
  final Future<Map<String, dynamic>> datos;
  final Future<void> Function() onRecargar;
  const EstudianteHorario({super.key, required this.datos, required this.onRecargar});

  @override
  State<EstudianteHorario> createState() => _EstudianteHorarioState();
}

class _EstudianteHorarioState extends State<EstudianteHorario> {
  int _vista = 0; // 0 agenda por día, 1 semanal
  late DateTime _sel = _hoyHabil();

  DateTime _hoyHabil() {
    return soloDia(DateTime.now()); // incluye domingo
  }

  DateTime _lunes() {
    final h = soloDia(DateTime.now());
    return h.subtract(Duration(days: h.weekday - 1)); // la semana va de lunes a domingo
  }

  void _aviso(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ───────────────────────── exportación ─────────────────────────
  String _ics(List<Map<String, dynamic>> cursos) {
    String d2(int n) => n.toString().padLeft(2, '0');
    String f(DateTime d) => '${d.year}${d2(d.month)}${d2(d.day)}T${d2(d.hour)}${d2(d.minute)}00';
    String esc(String t) => t.replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', ' ');
    const by = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    final ahora = DateTime.now();
    final b = StringBuffer('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//KampusCheck//Horario//ES\r\nCALSCALE:GREGORIAN\r\n');
    for (final c in cursos) {
      final dias = diasDeCurso(c).toList()..sort();
      final i = horaInicioDe(c);
      final fin = horaFinDe(c);
      if (dias.isEmpty || i == null || fin == null) continue;
      var dia = soloDia(ahora);
      while (!dias.contains(dia.weekday)) {
        dia = dia.add(const Duration(days: 1));
      }
      final ini = DateTime(dia.year, dia.month, dia.day, i.$1, i.$2);
      final fn = DateTime(dia.year, dia.month, dia.day, fin.$1, fin.$2);
      final lugar = [c['aula'], c['edificio']].where((x) => x != null && '$x'.isNotEmpty).join(' - ');
      b.write('BEGIN:VEVENT\r\nUID:${c['id']}@kampuscheck\r\nDTSTAMP:${f(ahora.toUtc())}Z\r\n'
          'DTSTART:${f(ini)}\r\nDTEND:${f(fn)}\r\n'
          'RRULE:FREQ=WEEKLY;BYDAY=${dias.map((x) => by[x - 1]).join(',')};COUNT=${dias.length * 16}\r\n'
          'SUMMARY:${esc('${c['nombre']}')}\r\nLOCATION:${esc(lugar)}\r\nDESCRIPTION:${esc('Docente: ${c['docenteNombre'] ?? ''}')}\r\nEND:VEVENT\r\n');
    }
    b.write('END:VCALENDAR\r\n');
    return b.toString();
  }

  String _csv(List<Map<String, dynamic>> cursos) {
    String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
    final b = StringBuffer('Curso;Código;Días;Inicio;Fin;Aula;Edificio;Docente\r\n');
    for (final c in cursos) {
      final i = horaInicioDe(c);
      final f = horaFinDe(c);
      b.write([
        q(c['nombre']),
        q(c['codigo'] ?? ''),
        q(c['dias'] ?? ''),
        i == null ? '' : '${i.$1.toString().padLeft(2, '0')}:${i.$2.toString().padLeft(2, '0')}',
        f == null ? '' : '${f.$1.toString().padLeft(2, '0')}:${f.$2.toString().padLeft(2, '0')}',
        q(c['aula'] ?? ''),
        q(c['edificio'] ?? ''),
        q(c['docenteNombre'] ?? ''),
      ].join(';'));
      b.write('\r\n');
    }
    return b.toString();
  }

  Future<void> _exportar(String nombre, String contenido, {String mime = 'text/csv', bool bom = true}) async {
    try {
      final ok = await guardarArchivoTexto(nombre, contenido, mimeType: mime, bom: bom);
      if (ok) _aviso('Archivo guardado.');
    } catch (_) {
      _aviso('No se pudo guardar el archivo.');
    }
  }

  // ───────────────────────── piezas ─────────────────────────
  Widget _selector() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final v in [(0, 'Agenda por día', Icons.view_agenda_outlined), (1, 'Semanal', Icons.view_week_outlined)])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _vista = v.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(color: _vista == v.$1 ? AppColors.campo : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(v.$3, size: 16, color: _vista == v.$1 ? AppColors.verde : AppColors.gris),
                    const SizedBox(width: 6),
                    Text(v.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _vista == v.$1 ? AppColors.texto : AppColors.gris)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  Widget _franjaDias(DateTime ahora) {
    final lunes = _lunes();
    return Row(children: [
      for (var i = 0; i < 7; i++)
        Builder(builder: (_) {
          final dia = lunes.add(Duration(days: i));
          final activo = dia == _sel;
          final esHoy = dia == soloDia(ahora);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _sel = dia),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: activo ? AppColors.verde : AppColors.tarjeta, borderRadius: BorderRadius.circular(14), border: Border.all(color: activo ? AppColors.verde : AppColors.borde)),
                child: Column(children: [
                  Text(esHoy ? 'HOY' : diasCorto[dia.weekday - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: activo ? Colors.black : AppColors.gris)),
                  const SizedBox(height: 2),
                  Text('${dia.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: activo ? Colors.black : AppColors.texto)),
                  if (esHoy) Icon(Icons.circle, size: 5, color: activo ? Colors.black : AppColors.verde) else const SizedBox(height: 5),
                ]),
              ),
            ),
          );
        }),
    ]);
  }

  Widget _tituloDia(DateTime dia, int n, DateTime ahora) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Row(children: [
          const Icon(Icons.event_available, color: AppColors.verde, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(fechaLarga(dia), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          chipEstado(dia == soloDia(ahora) ? '$n clase${n == 1 ? '' : 's'}' : (soloDia(ahora).add(const Duration(days: 1)) == dia ? 'Mañana' : '$n clase${n == 1 ? '' : 's'}'), AppColors.verde),
        ]),
      );

  Widget _claseCard(Clase k, DateTime ahora) {
    final c = k.curso;
    final hoy = soloDia(k.ini) == soloDia(ahora);
    final enCurso = hoy && !k.ini.isAfter(ahora) && k.fin.isAfter(ahora);
    final termino = hoy && !k.fin.isAfter(ahora);
    final reg = c['miRegistro'] as Map<String, dynamic>?;
    final registrado = enCurso && reg != null;
    final docente = '${c['docenteNombre'] ?? ''}'.trim();
    final radio = AsistenciaProvider.configDe(c)['radio'];

    Widget badge;
    if (enCurso) {
      badge = chipEstado('En curso', AppColors.verde, icono: Icons.circle);
    } else if (termino) {
      badge = chipEstado('Finalizada', AppColors.gris);
    } else if (hoy) {
      badge = chipEstado(enTiempo(k.ini.difference(ahora)), AppColors.gris, icono: Icons.schedule);
    } else {
      badge = chipEstado('Programada', AppColors.gris);
    }

    Widget pie;
    if (registrado) {
      final h = (reg['hora'] as Timestamp?)?.toDate();
      pie = Row(children: [
        const Icon(Icons.check_circle, size: 18, color: AppColors.verde),
        const SizedBox(width: 8),
        const Expanded(child: Text('Asistencia Registrada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.verde))),
        Text(h == null ? '' : ampm(h), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ]);
    } else if (hoy && !termino) {
      pie = Row(children: [
        const Icon(Icons.place_outlined, size: 16, color: AppColors.gris),
        const SizedBox(width: 8),
        Expanded(child: Text(enCurso ? 'Check-in abierto desde ${hm(k.ini)}' : 'Check-in abre ${hm(k.ini)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(8)),
          child: Text('Geocerca ${radio}m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]);
    } else {
      pie = Text(termino ? '● Clase finalizada' : '● Programada', style: const TextStyle(fontSize: 11, color: AppColors.gris));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(20), border: Border.all(color: enCurso ? AppColors.verde.withAlpha(120) : AppColors.borde)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${hm(k.ini)} - ${hm(k.fin)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text('• ${duracion(k.ini, k.fin)}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          const Spacer(),
          badge,
        ]),
        const SizedBox(height: 8),
        Text('${c['nombre']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.gris),
          const SizedBox(width: 6),
          Expanded(child: Text([c['aula'], c['edificio']].where((x) => x != null && '$x'.isNotEmpty).join('  •  '), style: const TextStyle(fontSize: 13, color: AppColors.gris))),
        ]),
        if (docente.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.person_outline, size: 16, color: AppColors.gris),
            const SizedBox(width: 6),
            Text(docente, style: const TextStyle(fontSize: 13, color: AppColors.gris)),
          ]),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(12)),
          child: pie,
        ),
      ]),
    );
  }

  Widget _claseCompacta(Clase k) {
    final c = k.curso;
    final docente = '${c['docenteNombre'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${hm(k.ini)} - ${hm(k.fin)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(duracion(k.ini, k.fin), style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        ]),
        const SizedBox(height: 4),
        Text('${c['nombre']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text([c['aula'], c['edificio'], if (docente.isNotEmpty) docente].where((x) => x != null && '$x'.isNotEmpty).join('  •  '), style: const TextStyle(fontSize: 12, color: AppColors.gris)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EstudianteFuturo(
      datos: widget.datos,
      onRecargar: widget.onRecargar,
      construir: (d) {
        final cursos = (d['cursos'] as List).cast<Map<String, dynamic>>();
        final ahora = DateTime.now();
        final delDia = clasesDelDia(cursos, _sel);
        final siguiente = _sel.add(const Duration(days: 1));
        final delSiguiente = clasesDelDia(cursos, siguiente);
        final lunes = _lunes();
        return [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SEMESTRE ${semestreActual()}', style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Text('Mi Horario', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          _selector(),
          const SizedBox(height: 14),
          if (cursos.isEmpty)
            const InfoBox(icono: Icons.event_busy, texto: 'Aún no tienes cursos. Cuando tu docente te matricule, tu horario aparecerá aquí.')
          else if (_vista == 0) ...[
            _franjaDias(ahora),
            const SizedBox(height: 10),
            _tituloDia(_sel, delDia.length, ahora),
            if (delDia.isEmpty) const InfoBox(icono: Icons.event_available, texto: 'Sin clases este día.'),
            for (final k in delDia) _claseCard(k, ahora),
            if (delSiguiente.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today, color: AppColors.verde, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(fechaLarga(siguiente), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                chipEstado(soloDia(ahora).add(const Duration(days: 1)) == siguiente ? 'Mañana' : etiquetaDia(siguiente, ahora), AppColors.gris),
              ]),
              const SizedBox(height: 10),
              for (final k in delSiguiente) _claseCompacta(k),
            ],
          ] else
            for (var i = 0; i < 7; i++) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(fechaLarga(lunes.add(Duration(days: i))), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: lunes.add(Duration(days: i)) == soloDia(ahora) ? AppColors.verde : AppColors.texto)),
              ),
              if (clasesDelDia(cursos, lunes.add(Duration(days: i))).isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Sin clases', style: TextStyle(fontSize: 12, color: AppColors.gris)))
              else
                for (final k in clasesDelDia(cursos, lunes.add(Duration(days: i)))) _claseCompacta(k),
            ],
          const SizedBox(height: 10),
          if (cursos.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
              child: Row(children: [
                const Icon(Icons.sync, color: AppColors.verde),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Sincronizar Calendario', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Archivo .ics para Google Calendar o iCal', style: TextStyle(fontSize: 11, color: AppColors.gris)),
                  ]),
                ),
                GestureDetector(
                  onTap: () => _exportar('horario_kampuscheck.ics', _ics(cursos), mime: 'text/calendar', bom: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.verde, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Exportar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _exportar('horario_kampuscheck.csv', _csv(cursos)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 8),
                  Text('Descargar Horario (CSV / Excel)', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ];
      },
    );
  }
}