import 'package:flutter/material.dart';
import '../../src/app_theme.dart';
import '../../src/horario.dart';
import '../../src/kampus_widgets.dart';
import 'estudiante_comun.dart';

/// Pestaña "Cursos": cursos inscritos con su control de faltas.
class EstudianteCursos extends StatefulWidget {
  final Future<Map<String, dynamic>> datos;
  final Future<void> Function() onRecargar;
  const EstudianteCursos({super.key, required this.datos, required this.onRecargar});

  @override
  State<EstudianteCursos> createState() => _EstudianteCursosState();
}

class _EstudianteCursosState extends State<EstudianteCursos> {
  String _filtro = 'Todos';

  bool _riesgo(Map<String, dynamic> c) => (c['faltas'] as int) >= (c['maxFaltas'] as int) - 1;

  Widget _puntos(int faltas, int maxF) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < maxF.clamp(0, 12); i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < faltas ? AppColors.rojo : AppColors.borde),
          ),
      ]);

  Widget _dato(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: AppColors.verde),
          const SizedBox(width: 6),
          Flexible(child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _card(Map<String, dynamic> c, DateTime ahora) {
    final maxF = c['maxFaltas'] as int;
    final faltas = c['faltas'] as int;
    final pct = c['porcentaje'] as double;
    final dictadas = c['dictadas'] as int;
    final perdida = faltas > maxF;
    final riesgo = faltas == maxF;
    final color = (perdida || riesgo) ? AppColors.rojo : AppColors.verde;
    final (etiqueta, icono) = perdida
        ? ('Pérdida', Icons.block)
        : riesgo
            ? ('En Riesgo', Icons.warning_amber)
            : faltas == 0
                ? ('Excelente', Icons.verified_outlined)
                : ('Normal', Icons.check_circle_outline);
    final p = proximaClase([c], ahora);
    final docente = '${c['docenteNombre'] ?? ''}'.trim();
    final codigo = '${c['codigo'] ?? ''}'.trim();
    final grupo = '${c['grupo'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (perdida || riesgo) ? AppColors.rojo.withAlpha(150) : AppColors.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${codigo.isEmpty ? '' : '$codigo  '}${grupo.isEmpty ? '' : 'G$grupo'}',
                style: const TextStyle(fontSize: 11, color: AppColors.gris, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          chipEstado(etiqueta, color, icono: icono),
        ]),
        const SizedBox(height: 6),
        Text('${c['nombre']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (docente.isNotEmpty) _dato(Icons.person_outline, docente),
          if ('${c['aula'] ?? ''}'.isNotEmpty) _dato(Icons.place_outlined, '${c['aula']}'),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Asistencia Global', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (pct / 100).clamp(0.0, 1.0).toDouble(), minHeight: 6, color: color, backgroundColor: AppColors.borde),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$dictadas clase${dictadas == 1 ? '' : 's'} dictada${dictadas == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
              Row(children: [
                Text('Faltas: $faltas/$maxF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: faltas == 0 ? AppColors.verde : AppColors.rojo)),
                const SizedBox(width: 4),
                _puntos(faltas, maxF),
              ]),
            ]),
          ]),
        ),
        if (perdida || riesgo) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.rojo.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.rojo, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  perdida ? 'Límite alcanzado: perdiste la asignatura por inasistencias.' : 'Alerta: 1 falta más causará pérdida por inasistencias.',
                  style: const TextStyle(fontSize: 12, color: AppColors.rojo),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.event_outlined, size: 16, color: AppColors.gris),
            SizedBox(width: 6),
            Text('Próxima clase:', style: TextStyle(fontSize: 12, color: AppColors.gris)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(8)),
            child: Text(p == null ? 'Sin horario' : (p.enCurso ? 'En curso' : '${etiquetaDia(p.inicio, ahora)} ${p.hora}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
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
        final enRiesgo = cursos.where(_riesgo).length;
        final visibles = cursos.where((c) => switch (_filtro) {
              'En Riesgo' => _riesgo(c),
              'Aprobando' => !_riesgo(c),
              _ => true,
            }).toList();
        return [
          Row(children: [
            const Icon(Icons.school_outlined, color: AppColors.verde),
            const SizedBox(width: 8),
            const Text('Cursos Inscritos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('● Semestre ${semestreActual()} • ${cursos.length} Materia${cursos.length == 1 ? '' : 's'} Activa${cursos.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [('Todos', cursos.length), ('En Riesgo', enRiesgo), ('Aprobando', cursos.length - enRiesgo)])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text('${f.$1} (${f.$2})'), selected: _filtro == f.$1, onSelected: (_) => setState(() => _filtro = f.$1)),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (cursos.isEmpty)
            const InfoBox(icono: Icons.school_outlined, texto: 'Aún no estás matriculado en ningún curso. Cuando tu docente cargue el padrón con tu matrícula o correo, aparecerá aquí.')
          else if (visibles.isEmpty)
            const InfoBox(icono: Icons.filter_alt_off, texto: 'No hay cursos en este filtro.')
          else
            for (final c in visibles) _card(c, ahora),
          const SizedBox(height: 4),
          const InfoBox(
            icono: Icons.info_outline,
            texto: 'Reglamento de Asistencia\nPierdes la asignatura si superas el 20% de inasistencias injustificadas. El límite se calcula sobre el total de sesiones de cada curso, definido por tu docente.',
          ),
        ];
      },
    );
  }
}