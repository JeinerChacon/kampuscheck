import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/validadores.dart';
import '../src/kampus_widgets.dart';
import 'access_granted_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _esEstudiante = true;
  bool _oculto = true;
  bool _acepto = true;
  bool _cargando = false;

  String? _errNombre, _errCorreo, _errCodigo, _errPass, _errPass2;
  String? _errGeneral;

  final _scroll = ScrollController();

  /// El botón solo se activa cuando TODO está completo y aceptaste los términos.
  bool get _completo =>
      _nombreCtrl.text.trim().isNotEmpty &&
      _correoCtrl.text.trim().isNotEmpty &&
      _codigoCtrl.text.trim().isNotEmpty &&
      _passCtrl.text.isNotEmpty &&
      _pass2Ctrl.text.isNotEmpty &&
      _acepto;

  /// Lista de problemas para mostrar junto al botón.
  List<String> get _problemas => [
        ?_errNombre,
        ?_errCorreo,
        ?_errCodigo,
        ?_errPass,
        ?_errPass2,
        ?_errGeneral,
      ];

  String _carrera = 'Ingeniería de Sistemas e Informática';
  String _depto = 'Departamento de Ciencias Básicas e Ingeniería';

  final _carreras = const [
    'Ingeniería de Sistemas e Informática',
    'Administración de Empresas',
    'Derecho',
    'Psicología',
  ];
  final _deptos = const [
    'Departamento de Ciencias Básicas e Ingeniería',
    'Departamento de Ciencias Sociales',
    'Departamento de Humanidades',
  ];

  /// Nivel de seguridad de 0 a 4
  int get _nivel {
    final p = _passCtrl.text;
    int n = 0;
    if (p.length >= 8) n++;
    if (RegExp(r'[A-Z]').hasMatch(p)) n++;
    if (RegExp(r'[0-9]').hasMatch(p)) n++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) n++;
    return n;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Lleva la pantalla hasta el cuadro de errores (queda junto al botón).
  void _mostrarErrores() {
    // Evita conservar un BuildContext/GlobalKey de un elemento que puede
    // desaparecer cuando cambia el estado de validación o se cierra la ruta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _registrar() async {
    final nombre = _nombreCtrl.text.trim();
    final correo = _correoCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();
    final pass = _passCtrl.text;

    setState(() {
      _errGeneral = null;
      _errNombre = nombre.isEmpty ? 'Ingresa tu nombre completo.' : null;
      _errCorreo = esCorreoPermitido(correo)
          ? null
          : 'Correo no válido: $mensajeCorreoInvalido.';
      _errCodigo = codigo.isEmpty
          ? (_esEstudiante
              ? 'Ingresa tu matrícula.'
              : 'Ingresa tu código de empleado.')
          : null;
      _errPass = pass.length >= 8
          ? null
          : 'La contraseña debe tener mínimo 8 caracteres.';
      _errPass2 = pass == _pass2Ctrl.text
          ? null
          : 'Las contraseñas no coinciden.';
    });
    if (_problemas.isNotEmpty) {
      _mostrarErrores();
      return;
    }

    setState(() => _cargando = true);
    try {
      final perfil = await AuthProvider.registrar(
        rol: _esEstudiante ? 'estudiante' : 'docente',
        nombre: nombre,
        correo: correo,
        password: pass,
        codigo: codigo,
        programa: _esEstudiante ? _carrera : _depto,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AccessGrantedPage(esEstudiante: _esEstudiante, perfil: perfil),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errGeneral = e.mensaje;
      });
      _mostrarErrores();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errGeneral = 'Error inesperado: $e';
      });
      _mostrarErrores();
    }
  }

  Widget _barraSeguridad() {
    final textoNivel = ['', 'Débil', 'Media', 'Alta', 'Contraseña segura'];
    return Column(
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: i < _nivel ? AppColors.verde : AppColors.borde,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Seguridad:',
                style: TextStyle(fontSize: 11, color: AppColors.gris)),
            Text(textoNivel[_nivel],
                style: const TextStyle(fontSize: 11, color: AppColors.verde)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const PillLabel('CONTROL DE ASISTENCIA DIGITAL', conPunto: true),
              const SizedBox(height: 14),
              const KampusLogo(),
              const SizedBox(height: 16),
              RoleTabs(
                esEstudiante: _esEstudiante,
                onChanged: (v) => setState(() {
                  _esEstudiante = v;
                  _errNombre = _errCorreo = _errCodigo = null;
                  _errPass = _errPass2 = _errGeneral = null;
                }),
              ),
              const SizedBox(height: 16),
              KampusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _esEstudiante
                            ? 'Crear Cuenta Estudiante'
                            : 'Crear Cuenta Docente',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                        _esEstudiante
                            ? 'Regístrate con tu correo y matrícula institucional para acceder a la asistencia digital y aula virtual.'
                            : 'Alta de catedrático para gestión de asistencia por geocerca, lista en tiempo real y aulas asignadas.',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.gris)),
                    const SizedBox(height: 18),
                    KampusField(
                      etiqueta: _esEstudiante
                          ? 'Nombre Completo'
                          : 'Nombre y Título Académico',
                      hint: _esEstudiante
                          ? 'Ej. Sofía Ramírez Valdés'
                          : 'Ej. Dra. Carmen Morales',
                      icono: Icons.person_outline,
                      controller: _nombreCtrl,
                      error: _errNombre,
                      onChanged: (_) => setState(() {
                        _errNombre = null;
                        _errGeneral = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    KampusField(
                      etiqueta: _esEstudiante
                          ? 'Correo Institucional'
                          : 'Correo Institucional Docente',
                      etiquetaDerecha: '@udla.edu.co / Gmail',
                      hint: _esEstudiante
                          ? 'Ej. s.ramirez@udla.edu.co'
                          : 'Ej. c.morales@udla.edu.co',
                      icono: Icons.alternate_email,
                      controller: _correoCtrl,
                      error: _errCorreo,
                      onChanged: (_) => setState(() {
                        _errCorreo = null;
                        _errGeneral = null;
                      }),
                      teclado: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    KampusField(
                      etiqueta: _esEstudiante
                          ? 'Código de Estudiante / Matrícula'
                          : 'Código de Empleado / Cédula Docente',
                      hint: _esEstudiante ? 'Ej. 20241092' : 'EJ. DOC-78249',
                      icono: _esEstudiante
                          ? Icons.pin_outlined
                          : Icons.badge_outlined,
                      controller: _codigoCtrl,
                      error: _errCodigo,
                      onChanged: (_) => setState(() {
                        _errCodigo = null;
                        _errGeneral = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    if (_esEstudiante)
                      KampusDropdown(
                        etiqueta: 'Carrera / Facultad',
                        icono: Icons.account_balance_outlined,
                        valor: _carrera,
                        opciones: _carreras,
                        onChanged: (v) => setState(() => _carrera = v),
                      )
                    else
                      KampusDropdown(
                        etiqueta: 'Departamento / Facultad',
                        icono: Icons.apartment,
                        valor: _depto,
                        opciones: _deptos,
                        onChanged: (v) => setState(() => _depto = v),
                      ),
                    const SizedBox(height: 14),
                    KampusField(
                      etiqueta: _esEstudiante
                          ? 'Contraseña'
                          : 'Contraseña de Acceso',
                      hint: 'Mínimo 8 caracteres seguros',
                      icono: Icons.lock_outline,
                      controller: _passCtrl,
                      error: _errPass,
                      esPassword: true,
                      oculto: _oculto,
                      onToggleOculto: () =>
                          setState(() => _oculto = !_oculto),
                      onChanged: (_) => setState(() {
                        _errPass = null;
                        _errGeneral = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _barraSeguridad(),
                    const SizedBox(height: 14),
                    KampusField(
                      etiqueta: 'Confirmar Contraseña',
                      hint: 'Repite tu contraseña de acceso',
                      icono: Icons.lock_clock_outlined,
                      controller: _pass2Ctrl,
                      error: _errPass2,
                      onChanged: (_) => setState(() {
                        _errPass2 = null;
                        _errGeneral = null;
                      }),
                      esPassword: true,
                      oculto: _oculto,
                      onToggleOculto: () =>
                          setState(() => _oculto = !_oculto),
                    ),
                    if (!_esEstudiante) ...[
                      const SizedBox(height: 14),
                      const InfoBox(
                        icono: Icons.verified_user,
                        texto:
                            'La asignación de cursos y geocercas se sincronizará automáticamente con tu código de catedrático del sistema SIA / Banner.',
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acepto,
                          activeColor: AppColors.verde,
                          onChanged: (v) =>
                              setState(() => _acepto = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(TextSpan(
                              text: 'Acepto los ',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.gris),
                              children: [
                                const TextSpan(
                                    text: 'Términos de Servicio',
                                    style: TextStyle(
                                        color: AppColors.verde,
                                        decoration:
                                            TextDecoration.underline)),
                                const TextSpan(text: ' y la '),
                                TextSpan(
                                    text: _esEstudiante
                                        ? 'Política de Geolocalización en Aula (10m)'
                                        : 'Protocolo de Asistencia Digital Docente',
                                    style: const TextStyle(
                                        color: AppColors.verde,
                                        decoration:
                                            TextDecoration.underline)),
                                const TextSpan(text: '.'),
                              ],
                            )),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_problemas.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.rojoFondo,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.rojo.withAlpha(90)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.error_outline,
                                  size: 18, color: AppColors.rojo),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('No se pudo crear la cuenta',
                                    style: TextStyle(
                                        color: AppColors.rojo,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ..._problemas.map((m) => Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text('• $m',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFFE9A5AD))),
                                )),
                          ],
                        ),
                      ),
                    PrimaryButton(
                      texto: _esEstudiante
                          ? 'Crear Cuenta de Estudiante'
                          : 'Crear Cuenta de Docente',
                      cargando: _cargando,
                      onPressed: _completo ? _registrar : null,
                    ),
                    if (!_completo && !_cargando)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Center(
                          child: Text(
                              'Completa todos los campos y acepta los términos para continuar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.gris)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text.rich(TextSpan(
                  text: '¿Ya tienes una cuenta registrada? ',
                  style: TextStyle(color: AppColors.texto, fontSize: 13),
                  children: [
                    TextSpan(
                        text: 'Iniciar Sesión',
                        style: TextStyle(
                            color: AppColors.verde,
                            fontWeight: FontWeight.bold)),
                  ],
                )),
              ),
              const SizedBox(height: 8),
              const Text('¿Problemas con tu registro? Contactar Mesa de Ayuda',
                  style: TextStyle(fontSize: 12, color: AppColors.gris)),
              const SecureFooter(),
            ],
          ),
        ),
      ),
    );
  }
}