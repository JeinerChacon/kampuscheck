/// Utilidades de horario: calcula cuál es la próxima clase de una lista de cursos.
library;

const _nombresDia = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']; // Abreviaturas para mostrar los días de la semana.
const _claves = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom']; // Claves normalizadas para reconocer los días en cursos.

// Convierte texto a minúsculas y quita tildes para facilitar comparaciones.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

String semestreActual([DateTime? f]) {
  final d = f ?? DateTime.now(); // Usa la fecha recibida o la fecha actual.
  return '${d.year}-${d.month <= 6 ? 1 : 2}'; // Codifica el año y el semestre correspondiente.
}

/// Días de cátedra como números de DateTime.weekday (1 = lunes ... 7 = domingo).
Set<int> diasDeCurso(Map<String, dynamic> c) {
  final lista = c['diasLista']; // Obtiene la lista de días si está disponible.
  final texto = _norm(lista is List ? lista.join('/') : '${c['dias'] ?? ''}'); // Normaliza la lista o el texto alternativo.
  return {
    for (var i = 0; i < 7; i++)
      if (texto.contains(_claves[i])) i + 1, // Convierte cada día reconocido a su número DateTime.weekday.
  };
}

// Extrae una hora y minuto del texto o devuelve ausencia si no hay coincidencia.
(int, int)? _hm(String? s) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s ?? ''); // Busca el formato de hora y minuto.
  if (m == null) return null; // Indica que no se encontró una hora válida.
  return (int.parse(m.group(1)!), int.parse(m.group(2)!)); // Convierte las partes de hora a enteros.
}

/// Hora de inicio / fin (formato HH:mm) con compatibilidad para cursos antiguos
/// que solo tenían "08:00 - 10:00" en `horario`.
(int, int)? horaInicioDe(Map<String, dynamic> c) =>
    // Prefiere la hora explícita y recurre al formato antiguo si falta.
    _hm(c['horaInicio'] as String?) ??
    _hm(RegExp(r'\d{1,2}:\d{2}').firstMatch('${c['horario'] ?? ''}')?.group(0));

(int, int)? horaFinDe(Map<String, dynamic> c) {
  final f = _hm(c['horaFin'] as String?); // Intenta obtener la hora de fin explícita.
  if (f != null) return f; // Devuelve la hora explícita cuando está presente.
  final todas = RegExp(r'\d{1,2}:\d{2}').allMatches('${c['horario'] ?? ''}').toList(); // Extrae las horas del formato antiguo.
  return todas.length > 1 ? _hm(todas[1].group(0)) : null; // Devuelve la segunda hora si existe.
}

bool cursoEsHoy(Map<String, dynamic> c, [DateTime? ahora]) =>
    diasDeCurso(c).contains((ahora ?? DateTime.now()).weekday); // Comprueba si el curso ocurre el día actual indicado.

String _dosDig(int n) => n.toString().padLeft(2, '0'); // Completa con cero los valores de un dígito.

// Agrupa un curso y sus tiempos calculados para mostrar la próxima clase.
class ProximaClase {
  final Map<String, dynamic> curso; // Guarda los datos originales del curso.
  final DateTime inicio; // Guarda la fecha y hora de inicio.
  final DateTime fin; // Guarda la fecha y hora de finalización.
  final DateTime ahora; // Guarda el instante usado como referencia del cálculo.
  const ProximaClase(this.curso, this.inicio, this.fin, this.ahora); // Crea el resultado inmutable del cálculo.

  bool get enCurso => !inicio.isAfter(ahora); // Indica si la hora de inicio ya llegó.

  bool get esHoy =>
      inicio.year == ahora.year && inicio.month == ahora.month && inicio.day == ahora.day; // Compara la fecha de inicio con la fecha de referencia.

  String get hora => '${_dosDig(inicio.hour)}:${_dosDig(inicio.minute)}'; // Formatea la hora de inicio como HH:mm.

  /// "En curso", "Inicia en 15 min", "Hoy 14:00", "Mañana 08:00", "Mié 08:00".
  String get cuando {
    if (enCurso) return 'En curso'; // Prioriza indicar que la clase ya comenzó.
    final min = inicio.difference(ahora).inMinutes; // Calcula los minutos hasta el inicio.
    if (min < 60) return 'Inicia en ${min < 1 ? 1 : min} min'; // Muestra la cuenta regresiva si falta menos de una hora.
    final dias = DateTime(inicio.year, inicio.month, inicio.day)
        .difference(DateTime(ahora.year, ahora.month, ahora.day))
        .inDays;
    if (dias == 0) return 'Hoy $hora'; // Etiqueta la clase si cae en la fecha actual.
    if (dias == 1) return 'Mañana $hora'; // Etiqueta la clase si cae al día siguiente.
    return '${_nombresDia[inicio.weekday - 1]} $hora'; // Muestra el día abreviado para fechas posteriores.
  }
}

/// Próxima clase (o la que está en curso) entre los cursos publicados. null si no hay.
ProximaClase? proximaClase(List<Map<String, dynamic>> cursos, [DateTime? ahoraOpc]) {
  final ahora = ahoraOpc ?? DateTime.now(); // Usa la referencia recibida o el instante actual.
  ProximaClase? mejor; // Reserva el candidato más cercano encontrado.
  for (final c in cursos) {
    if (c['estado'] == 'borrador') continue; // Omite cursos no publicados.
    final dias = diasDeCurso(c); // Obtiene los días en los que se dicta el curso.
    final ini = horaInicioDe(c); // Obtiene la hora de inicio del curso.
    final fin = horaFinDe(c); // Obtiene la hora de finalización del curso.
    if (dias.isEmpty || ini == null || fin == null) continue; // Omite cursos sin datos de horario suficientes.
    for (var d = 0; d < 8; d++) {
      final dia = DateTime(ahora.year, ahora.month, ahora.day + d); // Recorre el día actual y los siete siguientes.
      if (!dias.contains(dia.weekday)) continue; // Ignora fechas en las que no se dicta el curso.
      final i = DateTime(dia.year, dia.month, dia.day, ini.$1, ini.$2); // Combina la fecha con la hora de inicio.
      final f = DateTime(dia.year, dia.month, dia.day, fin.$1, fin.$2); // Combina la fecha con la hora de fin.
      if (f.isBefore(ahora)) continue; // ya terminó
      final cand = ProximaClase(c, i, f, ahora); // Crea el candidato para esta fecha.
      if (mejor == null || cand.inicio.isBefore(mejor.inicio)) mejor = cand; // Conserva la clase más próxima.
      break;
    }
  }
  return mejor;
}
