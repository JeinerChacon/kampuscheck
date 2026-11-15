import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/validadores.dart';
import '../src/kampus_widgets.dart';
import 'verify_code_page.dart';

// Solicita el correo institucional para iniciar el flujo de recuperación.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Controla el campo de correo y los estados de envío del formulario.
  final _correoCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    // Libera el controlador del campo al cerrar la pantalla.
    _correoCtrl.dispose();
    super.dispose();
  }

  // Valida el correo, solicita recuperación y avanza a la verificación.
  Future<void> _enviar() async {
    final correo = _correoCtrl.text.trim();
    // Evita enviar una dirección que no cumpla el formato permitido.
    if (!esCorreoPermitido(correo)) {
      setState(() => _error = mensajeCorreoInvalido);
      return;
    }
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      // Envía la solicitud mediante el proveedor de autenticación.
      await AuthProvider.enviarRecuperacion(correo);
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enviamos un enlace de recuperación a tu correo.'),
      ));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyCodePage(correo: correo)),
      );
    } on AuthException catch (e) {
      // Presenta el error del proveedor y restablece el estado del formulario.
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  // Construye el formulario de recuperación y sus accesos de navegación.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Forgot Password',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: AppColors.verde, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline,
                size: 18, color: Colors.black),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tarjeta,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 14),
                        SizedBox(width: 6),
                        Text('VOLVER AL LOGIN',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const PillLabel('CONTROL DE ASISTENCIA DIGITAL'),
              const SizedBox(height: 14),
              const KampusLogo(subtitulo: ''),
              const SizedBox(height: 16),
              KampusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.campo,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.lock_reset,
                          color: AppColors.verde, size: 26),
                    ),
                    const SizedBox(height: 16),
                    const Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Ingresa tu correo electrónico institucional registrado. Te enviaremos un código de seguridad de 6 dígitos para restablecer tu acceso.',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.gris, height: 1.4)),
                    const SizedBox(height: 20),
                    KampusField(
                      etiqueta: 'Correo Institucional',
                      etiquetaDerecha: 'Dominio @udla.edu.co',
                      hint: 'tu.correo@udla.edu.co',
                      icono: Icons.alternate_email,
                      controller: _correoCtrl,
                      error: _error,
                      teclado: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    const InfoBox(
                      icono: Icons.verified_user_outlined,
                      texto:
                          'Se enviará el enlace de verificación y código temporal únicamente al buzón universitario oficial.',
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      texto: 'Enviar Código de Recuperación',
                      cargando: _cargando,
                      onPressed: _enviar,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text.rich(TextSpan(
                          text: '¿Recordaste tu clave? ',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.gris),
                          children: [
                            TextSpan(
                                text: 'Iniciar Sesión',
                                style: TextStyle(color: AppColors.verde)),
                          ],
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const HelpDeskBar(pregunta: '¿Problemas con tu correo?'),
              const SecureFooter(),
            ],
          ),
        ),
      ),
    );
  }
}