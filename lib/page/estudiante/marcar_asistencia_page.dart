import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/asistencia_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/estudiante_provider.dart';
import '../../src/app_theme.dart';
import '../../src/kampus_widgets.dart';
import 'asistencia_resultado_page.dart';
import 'dialogo_justificacion.dart';


/// Marcado de asistencia del estudiante: escanea el QR dinámico del docente
/// (o escribe el código de 6 dígitos) y valida su ubicación GPS.
class MarcarAsistenciaPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final String sesionId;
  const MarcarAsistenciaPage({super.key, required this.perfil, required this.sesionId});

  @override
  State<MarcarAsistenciaPage> createState() => _MarcarAsistenciaPageState();
}

class _MarcarAsistenciaPageState extends State<MarcarAsistenciaPage> {
  final _codigo = TextEditingController();
  final _cam = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  Timer? _reloj;
  Position? _pos;
  String? _errorGps;
  bool _buscando = false;
  bool _enviando = false;
  bool _manual = false; // mostrar el campo del código de 6 dígitos
  String? _qrRaw; // QR leído
  String? _qrAviso; // mensaje del escáner
  Map<String, dynamic>? _s; // última versión de la sesión
  Map<String, dynamic>? _curso;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _ubicar();
    _cargarCurso();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
    _cam.dispose();
    super.dispose();
  }

  Future<void> _cargarCurso() async {
    try {
      final s = (await AsistenciaProvider.sesion(widget.sesionId).first).data();
      if (s == null) return;
      final c = await AsistenciaProvider.curso(s['cursoId'] as String);
      if (mounted) setState(() => _curso = c);
    } catch (_) {}
  }

  Future<void> _ubicar() async {
    setState(() {
      _buscando = true;
      _errorGps = null;
    });
    try {
      final p = await AsistenciaProvider.obtenerUbicacion();
      if (!mounted) return;
      setState(() {
        _pos = p;
        _buscando = false;
      });
      // Si el QR ya se leyó mientras llegaba el GPS, confirma de inmediato.
      if (_qrRaw != null && !_enviando && _s != null) _confirmar(_s!);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorGps = e.mensaje;
        _buscando = false;
      });
    }
  }

  void _alDetectar(BarcodeCapture cap) {
    if (_qrRaw != null || _enviando) return;
    for (final b in cap.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final p = raw.split('|');
      if (p.length != 3 || p[0] != 'KAMPUS') {
        setState(() => _qrAviso = 'Ese QR no es de KampusCheck.');
        continue;
      }
      if (p[1] != widget.sesionId) {
        setState(() => _qrAviso = 'Ese QR es de otra sesión.');
        continue;
      }
      setState(() {
        _qrRaw = raw;
        _qrAviso = null;
      });
      // El QR rota cada 1 min: si ya hay GPS, confirma al instante.
      if (_pos != null && _s != null) _confirmar(_s!);
      return;
    }
  }

  Future<void> _confirmar(Map<String, dynamic> s) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    final contexto = {'cursoNombre': s['cursoNombre'], 'aula': s['aula'], 'sesionId': widget.sesionId};
    final usaQr = _qrRaw != null;
    try {
      final r = await AsistenciaProvider.registrarAsistencia(
        perfil: widget.perfil,
        qr: usaQr ? _qrRaw : null,
        codigo: usaQr ? null : _codigo.text,
        posicion: _pos,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AsistenciaExitoPage(perfil: widget.perfil, datos: r)),
      );
    } on AsistenciaError catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _qrRaw = null; // permite volver a escanear
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AsistenciaErrorPage(perfil: widget.perfil, error: e, contexto: contexto)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _qrRaw = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  /// Justificación de inasistencia disponible mientras se marca la asistencia.
  Future<void> _justificar() async {
    final msg = ScaffoldMessenger.of(context);
    final r = await pedirJustificacion(
      context,
      detalle: 'Esta justificación es válida solo para esta clase.',
    );
    if (r == null) return;
    try {
      await EstudianteProvider.enviarSolicitud(
        perfil: widget.perfil,
        sesionId: widget.sesionId,
        motivo: r.motivo,
        adjuntoNombre: r.archivoNombre,
        adjunto: r.archivo,
      );
      msg.showSnackBar(const SnackBar(content: Text('Solicitud enviada. Tu docente la revisará.')));
    } on AuthException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  // ───────────────────────── widgets ─────────────────────────
  String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Widget _caja(String t, Widget hijo) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 10, color: AppColors.gris)),
            const SizedBox(height: 4),
            hijo,
          ]),
        ),
      );

  Widget _esquina({required bool arriba, required bool izquierda}) => Positioned(
        top: arriba ? 12 : null,
        bottom: arriba ? null : 12,
        left: izquierda ? 12 : null,
        right: izquierda ? null : 12,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: arriba ? const BorderSide(color: AppColors.verde, width: 3) : BorderSide.none,
              bottom: arriba ? BorderSide.none : const BorderSide(color: AppColors.verde, width: 3),
              left: izquierda ? const BorderSide(color: AppColors.verde, width: 3) : BorderSide.none,
              right: izquierda ? BorderSide.none : const BorderSide(color: AppColors.verde, width: 3),
            ),
          ),
        ),
      );

  Widget _boton(IconData i, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: AppColors.verde.withAlpha(120))),
          child: Icon(i, size: 18, color: AppColors.verde),
        ),
      );

  Widget _visor() {
    final leido = _qrRaw != null;
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _cam,
            onDetect: _alDetectar,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography_outlined, color: AppColors.gris, size: 36),
                  const SizedBox(height: 10),
                  const Text('No se pudo abrir la cámara.\nUsa el código de 6 dígitos.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gris, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
        _esquina(arriba: true, izquierda: true),
        _esquina(arriba: true, izquierda: false),
        _esquina(arriba: false, izquierda: true),
        _esquina(arriba: false, izquierda: false),
        Positioned(
          left: 0,
          right: 0,
          bottom: 56,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
              child: Text(
                leido ? '✓ QR leído, validando…' : (_qrAviso ?? 'Enfoca el código QR del proyector'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: leido ? AppColors.verde : (_qrAviso != null ? AppColors.rojo : AppColors.texto)),
              ),
            ),
          ),
        ),
        Positioned(left: 14, bottom: 12, child: _boton(Icons.flash_on, () => _cam.toggleTorch())),
        Positioned(right: 14, bottom: 12, child: _boton(Icons.cameraswitch_outlined, () => _cam.switchCamera())),
      ]),
    );
  }

  Widget _fila(IconData icono, String titulo, String detalle, String badge, bool ok, {bool pendiente = false}) {
    final color = pendiente ? AppColors.gris : (ok ? AppColors.verde : AppColors.rojo);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
          child: Icon(icono, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(detalle, style: const TextStyle(fontSize: 11, color: AppColors.gris)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(pendiente ? Icons.hourglass_empty : (ok ? Icons.check_circle : Icons.cancel), size: 13, color: color),
            const SizedBox(width: 4),
            Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marcar Asistencia', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AsistenciaProvider.sesion(widget.sesionId),
          builder: (context, snap) {
            final s = snap.data?.data();
            if (s == null) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
            _s = s;

            final cierra = (s['cierraEn'] as Timestamp).toDate();
            final pausada = s['pausada'] == true;
            final ref = pausada ? ((s['pausadaEn'] as Timestamp?)?.toDate() ?? DateTime.now()) : DateTime.now();
            final restante = cierra.difference(ref).isNegative ? Duration.zero : cierra.difference(ref);
            final abierta = s['estado'] == 'abierta' && restante > Duration.zero;

            final radio = (s['radio'] as num).toInt();
            final dist = _pos == null ? null : AsistenciaProvider.distanciaA(_pos!, s);
            final gpsOk = dist != null && dist <= radio + min(_pos!.accuracy, 25.0);
            final mockOk = _pos != null && !_pos!.isMocked;
            final manualOk = _codigo.text.trim().length == 6;
            final codigoOk = _qrRaw != null || manualOk;
            final listos = [gpsOk, mockOk, codigoOk].where((x) => x).length;
            final puede = abierta && !_enviando && codigoOk && _pos != null;

            final dn = '${s['docenteNombre'] ?? ''}'.trim();
            final docente = dn.isNotEmpty ? dn : '${_curso?['docenteNombre'] ?? ''}'.trim();
            final grupo = '${_curso?['grupo'] ?? ''}'.trim();

            return ListView(padding: const EdgeInsets.all(16), children: [
              const Center(child: PillLabel('CONTROL DE ASISTENCIA DIGITAL')),
              const SizedBox(height: 12),
              const KampusLogo(tamano: 20),
              const SizedBox(height: 14),

              // ── Materia en curso
              KampusCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('MATERIA EN CURSO', style: TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.bold)),
                    if ('${s['edificio'] ?? ''}'.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.verde.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                        child: Text('${s['edificio']}', style: const TextStyle(fontSize: 11, color: AppColors.verde)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text('${s['cursoNombre']}${grupo.isEmpty ? '' : ' • Grupo $grupo'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _caja('Ubicación asignada', Text('${s['aula'] ?? '---'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    _caja('Catedrático', Text(docente.isEmpty ? '---' : docente, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined, color: AppColors.rojo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Tiempo Restante', style: TextStyle(fontSize: 11, color: AppColors.gris)),
                          Text(pausada ? 'Registro en pausa' : (abierta ? '${_mmss(restante)} min restantes' : 'Sesión cerrada'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.rojo)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(10)),
                        child: Text('Rango: < ${radio}m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Escáner QR
              KampusCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Row(children: [
                    Icon(Icons.sync, color: AppColors.verde, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('QR Dinámico Rotatorio: cambia cada 1 min para evitar capturas y reenvíos ilegítimos.',
                          style: TextStyle(fontSize: 12, color: AppColors.gris)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _visor(),
                  const SizedBox(height: 4),
                  if (_qrRaw != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _qrRaw = null),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Escanear de nuevo'),
                    ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Telemetría
              KampusCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.shield_outlined, color: AppColors.verde, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Telemetría de Integridad Espacial', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                    Text('$listos/3 Listos', style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  _fila(
                    Icons.my_location,
                    'Ubicación GPS precisa',
                    _buscando
                        ? 'Buscando señal satelital…'
                        : (_errorGps ?? (dist == null ? 'Sin ubicación todavía' : 'A ${dist.round()} metros del docente (radio máx: ${radio}m)')),
                    _buscando ? 'Buscando' : (gpsOk ? 'Válido' : (_pos == null ? 'Sin GPS' : 'Fuera de rango')),
                    gpsOk,
                    pendiente: _buscando,
                  ),
                  _fila(
                    Icons.gpp_good_outlined,
                    'Seguridad del dispositivo',
                    _pos == null ? 'Se verifica con la ubicación' : (mockOk ? 'Sin software de ubicación falsa' : 'Ubicación simulada detectada'),
                    _pos == null ? 'Pendiente' : (mockOk ? 'Sin plagio' : 'Detectado'),
                    mockOk,
                    pendiente: _pos == null,
                  ),
                  _fila(
                    Icons.qr_code_scanner,
                    'Código de la sesión',
                    _qrRaw != null ? 'QR escaneado' : (manualOk ? 'Código de 6 dígitos ingresado' : 'Escanea el QR o escribe el código'),
                    codigoOk ? 'Listo' : 'Pendiente',
                    codigoOk,
                    pendiente: !codigoOk,
                  ),
                  GestureDetector(
                    onTap: _buscando ? null : _ubicar,
                    child: Row(children: [
                      const Icon(Icons.refresh, size: 16, color: AppColors.verde),
                      const SizedBox(width: 6),
                      Text(_buscando ? 'Actualizando ubicación…' : 'Actualizar mi ubicación', style: const TextStyle(fontSize: 12, color: AppColors.verde)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (!abierta && !pausada)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: InfoBox(icono: Icons.lock_outline, color: AppColors.rojo, texto: 'La ventana de registro ya cerró. Habla con tu docente.'),
                ),
              PrimaryButton(
                texto: 'Confirmar Asistencia Presencial',
                icono: Icons.how_to_reg,
                cargando: _enviando,
                onPressed: puede ? () => _confirmar(s) : null,
              ),
              const SizedBox(height: 12),

              // ── Alternativa: código de 6 dígitos
              GestureDetector(
                onTap: () => setState(() => _manual = !_manual),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borde)),
                  child: Row(children: [
                    const Icon(Icons.dialpad, color: AppColors.verde, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('¿Problemas con la cámara? Ingresar código de 6 dígitos',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.verde)),
                    ),
                    Icon(_manual ? Icons.expand_less : Icons.expand_more, color: AppColors.gris),
                  ]),
                ),
              ),
              if (_manual) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _codigo,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    helperText: 'Es el código que aparece bajo el QR en la pantalla del docente.',
                    filled: true,
                    fillColor: AppColors.campo,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 13, color: AppColors.gris),
                SizedBox(width: 6),
                Text('Tu ubicación solo se usa para validar tu presencia', style: TextStyle(fontSize: 11, color: AppColors.gris)),
              ]),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _justificar,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.assignment_ind_outlined, size: 18, color: AppColors.rojo),
                    SizedBox(width: 8),
                    Text('Solicitar justificación de inasistencia', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ]);
          },
        ),
      ),
    );
  }
}