import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/estudiante_provider.dart';
import '../../src/app_theme.dart';
import '../../src/horario.dart';
import '../../src/kampus_widgets.dart';
import 'estudiante_comun.dart';
import 'marcar_asistencia_page.dart';

const _ambar = kAmbar;

/// Pestaña "Dashboard" del estudiante: asistencia global, control de faltas por
/// curso y horario de hoy / mañana. Todo sale de los cursos donde el docente
/// lo matriculó (padrón) y de las actas de asistencia.
class EstudianteDashboard extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final Future<Map<String, dynamic>> datos;
  final Future<void> Function() onRecargar;
  const EstudianteDashboard({super.key, required this.perfil, required this.datos, required this.onRecargar});

  @override
  State<EstudianteDashboard> createState() => _EstudianteDashboardState();
}

class _EstudianteDashboardState extends State<EstudianteDashboard> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca textos de tiempo ("En 10 min", progreso de la sesión) sin recargar datos.
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _marcar(String sesionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarcarAsistenciaPage(perfil: widget.perfil, sesionId: sesionId),
      ),
    );
    if (mounted) widget.onRecargar();
  }

  // ───────────────────────── piezas ─────────────────────────
  Widget _chip(String t, Color c, {IconData? icono}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[Icon(icono, size: 13, color: c), const SizedBox(width: 4)],
          Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ]),
      );

  Widget _perfilCard(String? aula) {
    final p = widget.perfil;
    final nombre = '${p['nombre'] ?? 'Estudiante'}';
    final iniciales = nombre.trim().split(RegExp(r'\s+')).take(2).map((x) => x[0].toUpperCase()).join();
    return KampusCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.campo,
          child: Text(iniciales, style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('${p['carrera'] ?? '---'} • ID #${p['matricula'] ?? '---'}'.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: AppColors.gris)),
          ]),
        ),
        if (aula != null && aula.isNotEmpty) _chip(aula, AppColors.verde, icono: Icons.place_outlined),
      ]),
    );
  }

  Widget _estadisticas(Map<String, dynamic> d) {
    final pct = d['porcentaje'] as double;
    final faltas = d['faltas'] as int;
    final just = d['justificadas'] as int;
    final cumple = pct >= EstudianteProvider.asistenciaMinima;
    final color = cumple ? AppColors.verde : AppColors.rojo;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: KampusCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Asistencia Global', style: TextStyle(fontSize: 12, color: AppColors.gris)),
            const SizedBox(height: 6),
            Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(cumple ? Icons.verified_outlined : Icons.warning_amber, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(cumple ? 'Cumplimiento reglamentario' : 'Por debajo del mínimo',
                    style: TextStyle(fontSize: 11, color: color)),
              ),
            ]),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: KampusCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Inasistencias Totales', style: TextStyle(fontSize: 12, color: AppColors.gris)),
            const SizedBox(height: 6),
            Text('${faltas + just}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Faltas registradas', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
            Text('$just Justificada${just == 1 ? '' : 's'} • $faltas Injustificada${faltas == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.gris)),
          ]),
        ),
      ),
    ]);
  }

  Widget _tolerancia() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_outlined, size: 18, color: AppColors.verde),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tolerancia Institucional KampusCheck: pierdes la asignatura si superas el 20% de inasistencias injustificadas sobre las sesiones del curso (el límite se calcula por curso). Asistencia mínima requerida: 80%.',
              style: TextStyle(fontSize: 11, color: AppColors.gris),
            ),
          ),
        ]),
      );

  /// Avisos preventivos enviados por los docentes.
  Widget _avisos() {
    final correo = '${widget.perfil['correo'] ?? ''}'.trim().toLowerCase();
    final mat = '${widget.perfil['matricula'] ?? ''}'.trim();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EstudianteProvider.avisos(correo, mat),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? []).toList()
          ..sort((a, b) {
            final x = (a.data()['creadoEn'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final y = (b.data()['creadoEn'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return y.compareTo(x);
          });
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(children: [
            for (final d in docs.take(3))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAmbar.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAmbar.withAlpha(120)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notifications_active_outlined, color: kAmbar, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Aviso preventivo • ${d.data()['cursoNombre'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text('${d.data()['mensaje'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                    ]),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Widget _cursoCard(Map<String, dynamic> c, DateTime ahora) {
    final p = proximaClase([c], ahora);
    final faltas = c['faltas'] as int;
    final dictadas = c['dictadas'] as int;
    final pct = c['porcentaje'] as double;
    final miRegistro = c['miRegistro'] as Map<String, dynamic>?;
    final abierta = c['sesionAbierta'] != null;
    final enCurso = p != null && p.enCurso;
    final maxF = c['maxFaltas'] as int;

    final riesgo = faltas >= maxF - 1;
    final colorBarra = faltas >= maxF ? AppColors.rojo : (faltas == maxF - 1 ? AppColors.rojo : AppColors.verde);

    // Etiqueta superior
    String etiqueta = 'Sin horario';
    if (p != null) {
      final rango = '${etiquetaDia(p.inicio, ahora)} ${hm(p.inicio)} - ${hm(p.fin)}';
      etiqueta = enCurso ? 'EN CURSO • $rango' : '$rango • ${p.inicio.difference(ahora).inHours >= 24 ? 'Programada' : enTiempo(p.inicio.difference(ahora))}';
    }

    // Insignia derecha
    Widget insignia = const SizedBox.shrink();
    if (abierta && miRegistro != null) {
      insignia = _chip('Asistió', AppColors.verde, icono: Icons.check_circle_outline);
    } else if (abierta) {
      insignia = _chip('Registro abierto', _ambar, icono: Icons.sensors);
    } else if (enCurso) {
      insignia = _chip('En curso', AppColors.verde);
    } else if (p != null) {
      final dif = p.inicio.difference(ahora);
      insignia = _chip(dif.inHours >= 24 ? etiquetaDia(p.inicio, ahora) : enTiempo(dif), AppColors.gris, icono: Icons.schedule);
    }

    final docente = '${c['docenteNombre'] ?? ''}'.trim();
    final lugar = [
      c['aula'],
      c['edificio'],
      if (docente.isNotEmpty) 'Docente: $docente',
    ].where((x) => x != null && '$x'.trim().isNotEmpty).join(' • ');

    // Margen de faltas
    final (mensaje, colorMsg, iconoMsg) = faltas > maxF
        ? ('Superaste el 20% de inasistencias: perdiste la asignatura por fallas.', AppColors.rojo, Icons.block)
        : faltas == maxF
            ? ('Alerta: si acumulas 1 falta más perderás la asignatura por inasistencias.', AppColors.rojo, Icons.warning_amber)
            : faltas == 0
                ? ('Margen óptimo: sin faltas registradas en el ciclo.', AppColors.verde, Icons.check_circle_outline)
                : ('Margen: te quedan ${maxF - faltas} faltas antes de reprobar por inasistencia (límite: $maxF).', AppColors.verde, Icons.check_circle_outline);

    // Progreso de la sesión en curso
    Widget progresoSesion = const SizedBox.shrink();
    if (p != null && enCurso) {
      final total = p.fin.difference(p.inicio).inMinutes.clamp(1, 1 << 20).toInt();
      final trans = ahora.difference(p.inicio).inMinutes.clamp(0, total).toInt();
      final fr = trans / total;
      progresoSesion = Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Progreso de la sesión', style: TextStyle(fontSize: 11, color: AppColors.gris)),
            Text('$trans min / $total min (${(fr * 100).round()}%)', style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fr.toDouble(), minHeight: 5, color: AppColors.verde, backgroundColor: AppColors.borde)),
        ]),
      );
    }

    // Caja de estado del registro de hoy
    Widget cajaRegistro = const SizedBox.shrink();
    if (abierta && miRegistro != null) {
      final h = (miRegistro['hora'] as Timestamp?)?.toDate();
      final tarde = miRegistro['estado'] == 'tardanza';
      cajaRegistro = Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: (tarde ? _ambar : AppColors.verde).withAlpha(20), borderRadius: BorderRadius.circular(14), border: Border.all(color: (tarde ? _ambar : AppColors.verde).withAlpha(90))),
        child: Row(children: [
          Icon(Icons.check_circle, color: tarde ? _ambar : AppColors.verde, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tarde ? 'Tardanza • Asistencia Registrada' : 'Presente • Asistencia Registrada', style: TextStyle(fontWeight: FontWeight.bold, color: tarde ? _ambar : AppColors.verde)),
              Text('Check-in a las ${h == null ? '--' : hm(h)} vía GPS${miRegistro['distancia'] == null ? '' : ' (precisión ${miRegistro['distancia']} m)'}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
            ]),
          ),
        ]),
      );
    } else if (abierta) {
      cajaRegistro = Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _ambar.withAlpha(20), borderRadius: BorderRadius.circular(14), border: Border.all(color: _ambar.withAlpha(90))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.sensors, color: _ambar, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Tu docente abrió el registro de asistencia. Aún no has marcado tu presencia.', style: TextStyle(fontSize: 12))),
          ]),
          const SizedBox(height: 12),
          PrimaryButton(
            texto: 'Marcar Asistencia',
            icono: Icons.how_to_reg,
            onPressed: () => _marcar('${c['sesionAbierta']}'),
          ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: enCurso ? AppColors.verde.withAlpha(120) : AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(etiqueta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: enCurso ? AppColors.verde : AppColors.gris))),
          insignia,
        ]),
        const SizedBox(height: 8),
        Text('${c['nombre']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(lugar, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        cajaRegistro,
        progresoSesion,
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Clases dictadas: $dictadas', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
          Text('$faltas falta${faltas == 1 ? '' : 's'} de $maxF permitidas${riesgo && faltas <= maxF ? ' / RIESGO' : ''} (${pct.toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorBarra)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (pct / 100).clamp(0.0, 1.0).toDouble(), minHeight: 6, color: colorBarra, backgroundColor: AppColors.borde)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(iconoMsg, size: 14, color: colorMsg),
          const SizedBox(width: 6),
          Expanded(child: Text(mensaje, style: TextStyle(fontSize: 11, color: colorMsg))),
        ]),
      ]),
    );
  }

  Widget _seccionHorario(String titulo, IconData icono, DateTime dia, DateTime ahora, List<Map<String, dynamic>> cursos) {
    final clases = clasesDelDia(cursos, dia);
    final hoy = soloDia(dia) == soloDia(ahora);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        Icon(icono, size: 18, color: AppColors.verde),
        const SizedBox(width: 8),
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        Text('${diasLargo[dia.weekday - 1]}, ${dia.day} ${meses[dia.month - 1]}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
      ]),
      const SizedBox(height: 10),
      if (clases.isEmpty)
        const InfoBox(icono: Icons.event_available, texto: 'Sin clases programadas.')
      else
        for (final k in clases)
          Builder(builder: (_) {
            final enCurso = hoy && !k.ini.isAfter(ahora) && k.fin.isAfter(ahora);
            final termino = hoy && !k.fin.isAfter(ahora);
            final reg = k.curso['miRegistro'] != null && k.curso['sesionAbierta'] != null;
            final sub = '${hm(k.ini)} - ${hm(k.fin)}${enCurso ? ' (En curso ahora)' : (hoy && !termino ? ' (${enTiempo(k.ini.difference(ahora)).toLowerCase()})' : '')}';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(14), border: Border.all(color: enCurso ? AppColors.verde.withAlpha(120) : AppColors.borde)),
              child: Row(children: [
                Icon(Icons.circle, size: 9, color: enCurso ? AppColors.verde : AppColors.gris),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${k.curso['nombre']} • ${k.curso['aula'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                  ]),
                ),
                _chip(termino ? 'Finalizada' : (enCurso && reg ? 'Presente' : ampm(k.ini)), enCurso && reg ? AppColors.verde : AppColors.gris),
              ]),
            );
          }),
    ]);
  }

  // ───────────────────────── pantalla ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: widget.datos,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.verde));
        }
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            const InfoBox(icono: Icons.error_outline, color: AppColors.rojo, texto: 'No se pudieron cargar tus cursos. Revisa tu conexión y las reglas de Firestore.'),
            const SizedBox(height: 12),
            PrimaryButton(texto: 'Reintentar', icono: Icons.refresh, onPressed: widget.onRecargar),
          ]);
        }
        final d = snap.data!;
        final ahora = DateTime.now();
        final cursos = (d['cursos'] as List).cast<Map<String, dynamic>>();

        // Próxima clase / en curso primero.
        final orden = [...cursos]..sort((a, b) {
            final pa = proximaClase([a], ahora);
            final pb = proximaClase([b], ahora);
            if (pa == null && pb == null) return '${a['nombre']}'.compareTo('${b['nombre']}');
            if (pa == null) return 1;
            if (pb == null) return -1;
            return pa.inicio.compareTo(pb.inicio);
          });
        final proxima = proximaClase(cursos, ahora);
        final aula = proxima == null ? null : '${proxima.curso['aula'] ?? ''}';

        return RefreshIndicator(
          color: AppColors.verde,
          onRefresh: widget.onRecargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _perfilCard(aula),
              const SizedBox(height: 12),
              _estadisticas(d),
              const SizedBox(height: 12),
              _tolerancia(),
              _avisos(),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.bar_chart, color: AppColors.verde, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Cursos Activos & Control de Faltas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Text('${cursos.length} Materia${cursos.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
              ]),
              const SizedBox(height: 12),
              if (cursos.isEmpty)
                InfoBox(
                  icono: Icons.school_outlined,
                  texto: 'Aún no estás matriculado en ningún curso.\nCuando tu docente cargue el padrón con tu matrícula (${widget.perfil['matricula'] ?? '---'}) o tu correo, aparecerá aquí.',
                )
              else ...[
                for (final c in orden) _cursoCard(c, ahora),
                _seccionHorario('Horario de Hoy', Icons.calendar_today, soloDia(ahora), ahora, cursos),
                _seccionHorario('Horario de Mañana', Icons.update, soloDia(ahora).add(const Duration(days: 1)), ahora, cursos),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}