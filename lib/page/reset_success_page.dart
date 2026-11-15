import 'package:flutter/material.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import 'login_page.dart';

// Confirma el cambio de contraseña e informa la cuenta y el estado de seguridad.
class ResetSuccessPage extends StatelessWidget {
  // Correo cuya contraseña acaba de ser restablecida.
  final String correo;
  const ResetSuccessPage({super.key, required this.correo});

  // Presenta un dato del registro de operación con su icono y etiqueta.
  Widget _fila(IconData icono, String titulo, String valor, {Color? colorValor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.verdeOscuro.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: AppColors.verde),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.gris)),
                Text(valor,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorValor ?? AppColors.texto)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  // Compone el resumen exitoso y ofrece volver al inicio de sesión.
  Widget build(BuildContext context) {
    // Usa un texto alternativo si no se recibió una dirección de correo.
    final cuenta = correo.isEmpty ? 'tu.correo@udla.edu.co' : correo;
    // Obtiene la hora local que se muestra en el registro de operación.
    final ahora = TimeOfDay.now().format(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Reset Password',
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
              const KampusLogo(
                  subtitulo: 'PORTAL DE AUTENTICACIÓN SEGURA', tamano: 22),
              const SizedBox(height: 16),
              KampusCard(
                child: Column(
                  children: [
                    // Escudo con halo
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.verde.withAlpha(30),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.verdeOscuro,
                        ),
                        child: const Icon(Icons.verified_user,
                            size: 38, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const PillLabel('Contraseña Actualizada con Éxito',
                        conPunto: true),
                    const SizedBox(height: 14),
                    const Text('¡Listo! Tu acceso ha sido restablecido',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text(
                        'La nueva contraseña de tu cuenta institucional ha sido guardada satisfactoriamente en los servidores centrales de KampusCheck. Todas las sesiones activas anteriores han sido cerradas por seguridad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.gris, height: 1.4)),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.verdeOscuro.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REGISTRO DE OPERACIÓN',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  color: AppColors.verde)),
                          const SizedBox(height: 6),
                          _fila(Icons.alternate_email, 'Cuenta', cuenta),
                          _fila(Icons.schedule, 'Fecha y hora', 'Hoy, $ahora'),
                          _fila(Icons.shield, 'Estado de seguridad',
                              'Protección activa de credencial',
                              colorValor: AppColors.verde),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                texto: 'Ir a Iniciar Sesión',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tarjeta,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 20, color: AppColors.rojo),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(TextSpan(
                        text:
                            'Si no solicitaste este cambio, repórtalo de inmediato a la ',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.gris),
                        children: [
                          TextSpan(
                              text: 'Mesa de Ayuda universitaria',
                              style: TextStyle(
                                  color: AppColors.rojo,
                                  decoration: TextDecoration.underline)),
                          TextSpan(text: '.'),
                        ],
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}