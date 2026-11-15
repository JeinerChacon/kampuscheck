import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/asistencia_provider.dart';
import '../../src/app_theme.dart';
import '../../src/kampus_widgets.dart';

String _hora12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _iniciales(String nombre) => nombre
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

// ═══════════════════════════ ÉXITO ═══════════════════════════
class AsistenciaExitoPage extends StatelessWidget {
  final Map<String, dynamic> perfil;
  final Map<String, dynamic> datos; // resultado de registrarAsistencia
  const AsistenciaExitoPage({super.key, required this.perfil, required this.datos});

  Widget _bloque(String titulo, String valor, String sub) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 10, color: AppColors.gris, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(valor, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.gris)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nombre = '${perfil['nombre'] ?? 'Estudiante'}';
    final tarde = datos['estado'] == 'tardanza';
    final color = tarde ? const Color(0xFFF5B942) : AppColors.verde;
    final hora = datos['hora'] as DateTime;
    final docente = '${datos['docenteNombre'] ?? ''}'.trim();
    final grupo = '${datos['grupo'] ?? ''}'.trim();
    final id = 'KMP-${'${datos['sesionId']}'.substring(0, 6).toUpperCase()}-${'${perfil['uid']}'.substring(0, 4).toUpperCase()}';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Center(child: PillLabel('CONTROL DE ASISTENCIA DIGITAL')),
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.verde.withAlpha(30)),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.verde),
                  child: const Icon(Icons.check, size: 40, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('¡Asistencia Registrada con Éxito!', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'Presencia validada en ',
                style: const TextStyle(color: AppColors.gris),
                children: [
                  TextSpan(text: '${datos['aula'] ?? 'el aula'}', style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold)),
                  TextSpan(text: ' (a ${datos['distancia']} m del punto docente)'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            KampusCard(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: AppColors.tarjeta, child: Text(_iniciales(nombre), style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('MATRÍCULA: ${perfil['matricula'] ?? '---'}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                      child: Text(tarde ? '● TARDANZA' : '● PUNTUAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _bloque('ASIGNATURA', '${datos['cursoNombre']}', '${grupo.isEmpty ? '' : 'Grupo $grupo • '}${datos['aula'] ?? ''}'),
                  const SizedBox(width: 10),
                  _bloque('CATEDRÁTICO', docente.isEmpty ? '---' : docente, '${datos['edificio'] ?? ''}'),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.schedule, size: 18, color: AppColors.verde),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Hora de registro:', style: TextStyle(fontSize: 13, color: AppColors.gris))),
                      Text('${_hora12(hora)} • ${tarde ? 'Tardanza' : 'Tiempo reglamentario'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.my_location, size: 18, color: AppColors.verde),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Geocerca GPS:', style: TextStyle(fontSize: 13, color: AppColors.gris))),
                      Text('Validado a ${datos['distancia']} m (máx. ${datos['radio']} m)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.verde)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.fingerprint, color: AppColors.gris),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('COMPROBANTE DE REGISTRO', style: TextStyle(fontSize: 10, color: AppColors.gris, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Text(id, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              texto: 'Ingresar a mi Panel de Estudiante',
              icono: Icons.arrow_forward,
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
            const SizedBox(height: 12),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline, size: 13, color: AppColors.gris),
              SizedBox(width: 6),
              Text('Sesión cifrada institucionalmente', style: TextStyle(fontSize: 11, color: AppColors.gris)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════ ERROR ═══════════════════════════
class AsistenciaErrorPage extends StatelessWidget {
  final Map<String, dynamic> perfil;
  final AsistenciaError error;
  final Map<String, dynamic> contexto; // cursoNombre, aula
  const AsistenciaErrorPage({super.key, required this.perfil, required this.error, required this.contexto});

  /// 0 = distancia, 1 = código/sesión, 2 = GPS/ubicación simulada, -1 = otro motivo.
  int get _fallo => switch (error.tipo) {
        'distancia' => 0,
        'qr' || 'codigo' || 'cerrada' || 'pausada' => 1,
        'mock' || 'gps' => 2,
        _ => -1,
      };

  Widget _tarjeta({
    required IconData icono,
    required String titulo,
    required Widget cuerpo,
    required bool fallo,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: fallo ? AppColors.rojo.withAlpha(150) : AppColors.borde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (fallo ? AppColors.rojo : AppColors.gris).withAlpha(25), borderRadius: BorderRadius.circular(12)),
              child: Icon(icono, color: fallo ? AppColors.rojo : AppColors.gris),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (fallo ? AppColors.rojo : AppColors.gris).withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Text(fallo ? 'DETECTADO' : 'Secundario', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fallo ? AppColors.rojo : AppColors.gris)),
            ),
          ]),
          const SizedBox(height: 12),
          cuerpo,
        ]),
      );

  Text _txt(String t) => Text(t, style: const TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.4));

  @override
  Widget build(BuildContext context) {
    final nombre = '${perfil['nombre'] ?? 'Estudiante'}';
    final aula = '${contexto['aula'] ?? 'el aula'}';
    final f = _fallo;
    final ahora = DateTime.now();
    final incidente = '#ERR-${error.tipo.toUpperCase()}-${1000 + ahora.millisecondsSinceEpoch % 9000}';

    final d = error.distancia;
    final r = error.radio;

    final cuerpoDistancia = f == 0 && d != null && r != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(
              style: const TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.4),
              children: [
                const TextSpan(text: 'Tu ubicación actual está a '),
                TextSpan(text: '$d metros', style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold)),
                TextSpan(text: ' del $aula. El docente configuró una geocerca de '),
                TextSpan(text: '$r metros máximos', style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold)),
                const TextSpan(text: '. Debes estar presente en el salón físico.'),
              ],
            )),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Margen admitido (${r}m)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text('${d}m detectados', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.rojo)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (r / d).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                color: AppColors.verde,
                backgroundColor: AppColors.rojo.withAlpha(150),
              ),
            ),
          ])
        : _txt('Tu ubicación debe estar dentro del radio que configuró el docente para esta sesión.');

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Center(child: PillLabel('CONTROL DE ASISTENCIA DIGITAL')),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.rojo.withAlpha(30)),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.rojo.withAlpha(110)),
                child: const Icon(Icons.close, size: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('No se pudo registrar la asistencia', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('La validación presencial no cumplió con los parámetros de seguridad establecidos por el docente.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.gris)),
          const SizedBox(height: 18),
          KampusCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(backgroundColor: AppColors.campo, child: Icon(Icons.person, color: AppColors.texto)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Matrícula: ${perfil['matricula'] ?? '---'}', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.rojo.withAlpha(40), borderRadius: BorderRadius.circular(20)),
                  child: const Text('No Verificado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.rojo)),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Asignatura & Espacio', style: TextStyle(fontSize: 11, color: AppColors.gris)),
                    Text('${contexto['cursoNombre'] ?? '---'} • $aula', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hora de Intento', style: TextStyle(fontSize: 11, color: AppColors.gris)),
                  Row(children: [
                    const Icon(Icons.schedule, size: 14),
                    const SizedBox(width: 4),
                    Text(_hora12(ahora), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('DIAGNÓSTICO DEL SENSOR', style: TextStyle(fontSize: 11, color: AppColors.gris, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text(f >= 0 ? '1 de 3 parámetros vulnerados' : 'Registro rechazado', style: const TextStyle(fontSize: 11, color: AppColors.rojo, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          if (f == -1)
            _tarjeta(
              icono: Icons.gpp_bad_outlined,
              titulo: switch (error.tipo) {
                'padron' => 'No figuras en el padrón',
                'duplicada' => 'Ya registraste tu asistencia',
                'expulsado' => 'Registro anulado por el docente',
                'dispositivo' => 'Dispositivo ya utilizado en esta clase',
                _ => 'Registro rechazado',
              },
              fallo: true,
              cuerpo: _txt(error.mensaje),
            ),
          _tarjeta(
            icono: Icons.location_off,
            titulo: 'Distancia Fuera de Rango',
            fallo: f == 0,
            cuerpo: cuerpoDistancia,
          ),
          _tarjeta(
            icono: Icons.qr_code_2,
            titulo: 'Código QR Expirado o Inválido',
            fallo: f == 1,
            cuerpo: _txt(f == 1
                ? '${error.mensaje} Escanea de nuevo el QR proyectado o pide al docente el código de 6 dígitos.'
                : 'El código dinámico proyectado en pizarra puede caducar o el docente puede cerrar anticipadamente la ventana de recepción.'),
          ),
          _tarjeta(
            icono: Icons.shield_outlined,
            titulo: 'Permiso GPS o Ubicación Simulada',
            fallo: f == 2,
            cuerpo: _txt(f == 2
                ? error.mensaje
                : 'Debe certificarse la señal satelital de tu teléfono; no se admite software de falseo de posición.'),
          ),
          const SizedBox(height: 6),
          PrimaryButton(
            texto: 'Reintentar Escaneo y Localización',
            icono: Icons.refresh,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Geolocator.openLocationSettings(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.my_location, size: 18, color: AppColors.verde),
                SizedBox(width: 8),
                Text('Activar Alta Precisión GPS / Configuración', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('ID de Incidencia: $incidente', style: const TextStyle(fontSize: 11, color: AppColors.gris))),
        ]),
      ),
    );
  }
}