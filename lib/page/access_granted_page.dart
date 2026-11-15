import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import 'auth_gate.dart';
import 'login_page.dart';
import '../src/app_theme.dart';
import '../src/horario.dart';
import '../src/kampus_widgets.dart';

class AccessGrantedPage extends StatefulWidget {
  final bool esEstudiante;
  /// Datos del perfil leídos de Firestore (colección "usuarios").
  final Map<String, dynamic> perfil;
  const AccessGrantedPage({
    super.key,
    required this.esEstudiante,
    this.perfil = const {},
  });

  @override
  State<AccessGrantedPage> createState() => _AccessGrantedPageState();
}

class _AccessGrantedPageState extends State<AccessGrantedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Segundos que se muestra esta pantalla antes de pasar al panel.
  static const int _segundos = 7;

  String _dato(String clave, String porDefecto) {
    final v = widget.perfil[clave];
    return (v is String && v.isNotEmpty) ? v : porDefecto;
  }

  @override
  void initState() {
    super.initState();
    // Barra de progreso: _segundos segundos
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: _segundos))
      ..forward();
    _ctrl.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _irAlPanel();
    });
  }

  bool _navegado = false;

  /// Reemplaza TODA la pila por el panel del rol (no se puede volver atrás).
  void _irAlPanel() {
    if (_navegado || !mounted) return;
    _navegado = true;
    final perfil = {
      'rol': widget.esEstudiante ? 'estudiante' : 'docente',
      ...widget.perfil,
    };
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => panelPorRol(perfil)),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _tarjetaInterna({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // Cursos reales del usuario (docente: los que dicta; estudiante: donde está matriculado).
  late final Future<List<Map<String, dynamic>>> _cursos = _cargarCursos();

  Future<List<Map<String, dynamic>>> _cargarCursos() async {
    try {
      final col = FirebaseFirestore.instance.collection('cursos');
      final q = widget.esEstudiante
          ? col.where('matriculas', arrayContains: _dato('matricula', ''))
          : col.where('docenteUid', isEqualTo: widget.perfil['uid']);
      final r = await q.get();
      return r.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Widget _proximaClase(String titulo, String vacio) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cursos,
      builder: (context, snap) {
        final cargando = snap.connectionState != ConnectionState.done;
        final p = cargando ? null : proximaClase(snap.data ?? const []);
        Color color = AppColors.gris;
        Color fondo = AppColors.tarjeta;
        if (p != null && p.enCurso) {
          color = AppColors.verde;
          fondo = AppColors.verde.withAlpha(30);
        } else if (p != null && p.inicio.difference(p.ahora).inMinutes < 60) {
          color = AppColors.rojo;
          fondo = AppColors.rojoFondo;
        }
        final c = p?.curso;
        final lugar = c == null
            ? ''
            : [c['aula'], c['edificio'], if ('${c['grupo'] ?? ''}'.isNotEmpty) 'Grupo ${c['grupo']}']
                .where((x) => x != null && '$x'.trim().isNotEmpty)
                .join(' • ');
        return _tarjetaInterna(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(titulo,
                      style: const TextStyle(fontSize: 10, color: AppColors.gris)),
                  if (p != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: fondo, borderRadius: BorderRadius.circular(10)),
                      child: Text(p.cuando,
                          style: TextStyle(fontSize: 10, color: color)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (cargando)
                const Text('Buscando tu horario…',
                    style: TextStyle(fontSize: 13, color: AppColors.gris))
              else if (p == null) ...[
                const Text('Sin clases programadas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(vacio,
                    style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              ] else ...[
                Text('${c!['nombre']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(lugar,
                    style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _contenidoEstudiante() {
    return Column(
      children: [
        _tarjetaInterna(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dato('nombre', 'Estudiante'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        'ID: ${_dato('matricula', '---')} • ${_dato('carrera', '---')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.gris)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _proximaClase('PRÓXIMA CLASE',
            'Cuando tu docente te matricule en un curso, tu horario aparecerá aquí.'),
      ],
    );
  }

  Widget _contenidoSoporte() {
    return Column(
      children: [
        _tarjetaInterna(
          child: Row(
            children: [
              const Icon(Icons.support_agent, color: AppColors.verde, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dato('nombre', 'Agente de soporte'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text('Mesa de Ayuda KampusCheck',
                        style: TextStyle(fontSize: 11, color: AppColors.gris)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const InfoBox(
          icono: Icons.forum_outlined,
          texto: 'Panel de Soporte\nAtiende los tickets de estudiantes y docentes.',
        ),
      ],
    );
  }

  Widget _contenidoDocente() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.campo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.verde),
                  SizedBox(width: 6),
                  Text('Docente Titular',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text('ID: ${_dato('codigoEmpleado', '---')}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.gris, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 14),
        _tarjetaInterna(
          child: Row(
            children: [
              const Icon(Icons.account_balance, color: AppColors.verde),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dato('departamento', 'Facultad'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Ciclo Lectivo • Semestre ${semestreActual()}',
                        style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _proximaClase('SIGUIENTE CLASE PROGRAMADA',
            'Aún no tienes cursos. Créalos desde "Mis Cursos" y tu próxima clase aparecerá aquí.'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _cursos,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            final hay = (snap.data ?? const []).isNotEmpty;
            return InfoBox(
              icono: Icons.fact_check_outlined,
              texto: hay
                  ? 'Módulo de Asistencia Activo\nListo para abrir toma de lista de tus cursos.'
                  : 'Módulo de Asistencia\nCrea tu primer curso para habilitar la toma de asistencia.',
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final est = widget.esEstudiante;
    final nombre = _dato('nombre', est ? 'Estudiante' : 'Docente');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const KampusLogo(tamano: 22),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.verde.withAlpha(30),
                ),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.verde,
                  ),
                  child: const Icon(Icons.check, size: 40, color: Colors.black),
                ),
              ),
              const SizedBox(height: 14),
              if (!est) ...[
                const PillLabel('ACCESO CONCEDIDO'),
                const SizedBox(height: 10),
              ],
              Text(est ? '¡Acceso Concedido!' : '¡Autenticación Exitosa!',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text.rich(TextSpan(
                text: 'Bienvenido, ',
                style: const TextStyle(color: AppColors.gris),
                children: [
                  TextSpan(
                      text: nombre,
                      style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.bold)),
                  if (est) const TextSpan(text: ' (Estudiante)'),
                ],
              )),
              const SizedBox(height: 18),
              KampusCard(
                padding: const EdgeInsets.all(14),
                child: est
                    ? _contenidoEstudiante()
                    : (widget.perfil['rol'] == 'soporte'
                          ? _contenidoSoporte()
                          : _contenidoDocente()),
              ),
              const SizedBox(height: 14),

              // Barra de progreso animada
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final pct = (_ctrl.value * 100).round();
                  final seg = (_segundos - (_ctrl.value * _segundos)).ceil();
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              est
                                  ? 'Ingresando a tu panel de clases en ${seg}s...'
                                  : 'Redirigiendo a tu panel docente en ${seg}s ...',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.texto)),
                          Text('$pct%',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.verde)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _ctrl.value,
                          minHeight: 8,
                          backgroundColor: AppColors.tarjeta,
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.verde),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                texto: est
                    ? 'Ingresar a mi Panel de Estudiante'
                    : 'Entrar al Panel Docente Ahora',
                icono: Icons.arrow_forward,
                onPressed: _irAlPanel,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await AuthProvider.cerrarSesion();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 16, color: AppColors.gris),
                label: const Text('Cerrar sesión',
                    style: TextStyle(color: AppColors.gris, fontSize: 12)),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.gris),
                  const SizedBox(width: 6),
                  Text(
                      est
                          ? 'Sesión cifrada institucionalmente'
                          : 'Sesión encriptada de alta confianza activa',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.gris)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}