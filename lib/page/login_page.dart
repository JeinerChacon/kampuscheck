import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/validadores.dart';
import '../src/kampus_widgets.dart';
import 'access_granted_page.dart';
import 'forgot_password_page.dart';
import 'auth_gate.dart';
import 'register_page.dart';
import 'registro_soporte_page.dart';
import 'soporte/soporte_ayuda_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _esEstudiante = true;
  bool _esSoporte = false; // ingreso directo como agente de soporte
  bool _oculto = true;
  bool _recordar = false;
  bool _cargando = false;

  int _intentos = 0; // intentos fallidos de credenciales (máx. 3)
  bool _mostrarBanner = false; // solo después de intentar entrar
  final _scroll = ScrollController();
  String _mensajeError =
      'Contraseña o correo no coinciden, por favor intenta de nuevo.';
  String? _errorCorreo;
  String? _errorPass;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _subirAlAviso() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _iniciarSesion() async {
    final correo = _correoCtrl.text.trim();
    final pass = _passCtrl.text;

    // 1) Validación local: solo marca los campos, NO cuenta como intento.
    setState(() {
      _mostrarBanner = false;
      _errorCorreo = correo.isEmpty
          ? 'Ingresa tu correo'
          : (esCorreoPermitido(correo) ? null : mensajeCorreoInvalido);
      _errorPass = pass.isEmpty
          ? 'Ingresa tu contraseña'
          : (pass.length >= 8 ? null : 'Mínimo 8 caracteres');
    });
    if (_errorCorreo != null || _errorPass != null) return;

    // 2) Validación real contra Firebase
    setState(() => _cargando = true);
    try {
      final perfil = await AuthProvider.iniciarSesion(
        correo: correo,
        password: pass,
        rolEsperado: _esSoporte ? 'soporte' : (_esEstudiante ? 'estudiante' : 'docente'),
      );
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _intentos = 0;
      });
      if (_esSoporte) {
        // Soporte entra directo a su panel (sin pasar por el de estudiante).
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => panelPorRol(perfil)),
          (_) => false,
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AccessGrantedPage(
              esEstudiante: _esEstudiante, perfil: perfil),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _intentos++;
        _mostrarBanner = true;
        _mensajeError = e.mensaje;
        _errorPass = 'Revisa tu contraseña';
      });
      _subirAlAviso();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _intentos++;
        _mostrarBanner = true;
        _mensajeError = 'Error inesperado: $e';
      });
      _subirAlAviso();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayError = _mostrarBanner && _intentos > 0;
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
              const SizedBox(height: 20),
              RoleTabs(
                esEstudiante: _esEstudiante,
                esSoporte: _esSoporte,
                onSoporte: () => setState(() {
                  _esSoporte = true;
                  _intentos = 0;
                  _mostrarBanner = false;
                  _errorCorreo = null;
                  _errorPass = null;
                }),
                onChanged: (v) => setState(() {
                  _esSoporte = false;
                  _esEstudiante = v;
                  _intentos = 0;
                  _mostrarBanner = false;
                  _errorCorreo = null;
                  _errorPass = null;
                }),
              ),
              const SizedBox(height: 18),

              // Banner de error
              if (hayError) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.rojoFondo,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.rojo.withAlpha(90)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Credenciales No Válidas',
                                style: TextStyle(
                                    color: AppColors.rojo,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7A1424),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$_intentos/3 Intentos',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                          _intentos >= 3
                              ? 'Intentos agotados. Usa "¿Olvidaste tu contraseña?" para restablecer tu acceso.'
                              : _mensajeError,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFE9A5AD))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              KampusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Iniciar Sesión',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                        'Ingresa con tus credenciales institucionales para el registro de asistencia.',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.gris)),
                    const SizedBox(height: 18),
                    KampusField(
                      etiqueta: 'Correo Institucional',
                      hint: _esSoporte
                          ? 'Ej. agente@udla.edu.co'
                          : _esEstudiante
                              ? 'Ej. tu.correo@udla.edu.co'
                              : 'Ej. c.mendoza@udla.edu.co',
                      icono: Icons.alternate_email,
                      controller: _correoCtrl,
                      teclado: TextInputType.emailAddress,
                      error: _errorCorreo,
                      onChanged: (_) => setState(() => _errorCorreo = null),
                    ),
                    const SizedBox(height: 16),
                    KampusField(
                      etiqueta: 'Contraseña',
                      hint: 'Ingresa tu clave',
                      icono: Icons.lock_outline,
                      controller: _passCtrl,
                      esPassword: true,
                      oculto: _oculto,
                      onToggleOculto: () =>
                          setState(() => _oculto = !_oculto),
                      error: _errorPass,
                      onChanged: (_) => setState(() => _errorPass = null),
                      widgetDerecha: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ForgotPasswordPage())),
                        child: const Text('¿Olvidaste tu contraseña?',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.verde)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: _recordar,
                          activeColor: AppColors.verde,
                          onChanged: (v) =>
                              setState(() => _recordar = v ?? false),
                        ),
                        const Text('Recordar sesión en este dispositivo',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.gris)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      texto: 'Iniciar Sesión',
                      cargando: _cargando,
                      onPressed: _intentos >= 3 ? null : _iniciarSesion,
                    ),
                    const SizedBox(height: 14),
                    InfoBox(
                      icono: Icons.fiber_manual_record,
                      texto: _esSoporte
                          ? 'Portal de Soporte activo para atender tickets de la Mesa de Ayuda.'
                          : _esEstudiante
                              ? 'Portal Estudiantil activo para verificación biométrica y asistencia áulica.'
                              : 'Portal Docente activo para toma de lista y gestión de geocercas.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SoporteAyudaPage(),
                    ),
                  ),
                  icon: const Icon(Icons.support_agent, size: 18, color: AppColors.verde),
                  label: const Text('¿Necesitas ayuda? Mesa de soporte',
                      style: TextStyle(color: AppColors.verde, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 4),

              // Ir a registro
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _esSoporte
                            ? const RegistroSoportePage()
                            : const RegisterPage())),
                child: const Text.rich(TextSpan(
                  text: '¿No tienes cuenta? ',
                  style: TextStyle(color: AppColors.gris, fontSize: 13),
                  children: [
                    TextSpan(
                        text: 'Regístrate',
                        style: TextStyle(
                            color: AppColors.verde,
                            fontWeight: FontWeight.bold)),
                  ],
                )),
              ),
              const SizedBox(height: 14),
              const SecureFooter(),
            ],
          ),
        ),
      ),
    );
  }
}