import 'dart:math';

/// Reglas de inasistencia dinámicas por curso.
///
/// El docente define cuántas sesiones tiene el curso en el semestre
/// (`sesionesPlanificadas`, distinto en cada curso). La pérdida por fallas es
/// al superar el 20 % de ese total. Si al final solo se dictaron 28 de 30,
/// el docente ajusta el total a 28 y todo se recalcula sobre esas 28.
const double kLimiteFallas = 0.20;

/// Mínimo usado en cursos antiguos que no tienen sesiones planificadas.
const int _baseCursosAntiguos = 16;

int sesionesPlanificadas(Map<String, dynamic> curso) =>
    (curso['sesionesPlanificadas'] as num?)?.toInt() ?? 0;

/// Total de sesiones sobre el que se calcula el 20 %.
int totalSesionesBase(Map<String, dynamic> curso, int dictadas) {
  final p = sesionesPlanificadas(curso);
  return p > 0 ? max(p, dictadas) : max(dictadas, _baseCursosAntiguos);
}

/// Faltas injustificadas permitidas (se pierde al superarlas).
int maxFaltasDe(Map<String, dynamic> curso, int dictadas) =>
    (totalSesionesBase(curso, dictadas) * kLimiteFallas).floor();

bool perdioPorFallas(int faltas, int maxFaltas) => faltas > maxFaltas;