/// Validación de correos en un solo lugar.
///
/// Para producción: pon [permitirCorreosDePrueba] en false y solo se
/// aceptarán correos institucionales (@udla.edu.co).
const bool permitirCorreosDePrueba = true; // Habilita temporalmente los dominios permitidos para pruebas.

/// Dominios institucionales (también acepta subdominios,
/// ej. estudiantes.udla.edu.co).
const List<String> _dominiosInstitucionales = ['udla.edu.co']; // Lista los dominios institucionales aceptados.

/// Dominios exactos permitidos solo para pruebas.
const List<String> _dominiosPrueba = ['gmail.com']; // Lista los dominios aceptados solo en modo de pruebas.

final RegExp _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'); // Comprueba la estructura básica de una dirección de correo.

// Informa los dominios aceptados cuando el correo no supera la validación.
const String mensajeCorreoInvalido =
    'Usa tu correo @udla.edu.co (o Gmail para pruebas)';

bool esCorreoPermitido(String correo) {
  final c = correo.trim().toLowerCase(); // Normaliza espacios y mayúsculas antes de validar.
  if (!_formatoCorreo.hasMatch(c)) return false; // Rechaza direcciones con formato inválido.

  final dominio = c.split('@').last; // Extrae la parte posterior al símbolo @.
  final institucional = _dominiosInstitucionales
      .any((d) => dominio == d || dominio.endsWith('.$d')); // Acepta el dominio institucional y sus subdominios.
  final prueba = permitirCorreosDePrueba && _dominiosPrueba.contains(dominio); // Acepta dominios de prueba solo si están habilitados.

  return institucional || prueba; // Permite el correo si cumple cualquiera de las políticas.
}
