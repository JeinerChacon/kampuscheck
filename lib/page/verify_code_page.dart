import 'dart:async';
import 'package:flutter/material.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import 'reset_success_page.dart';

// Verifica el código de recuperación y recopila la nueva contraseña.
class VerifyCodePage extends StatefulWidget {
  final String correo;
  const VerifyCodePage({super.key, required this.correo});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  // Controla el código, el foco de entrada y los campos de contraseña.
  final _codigoCtrl = TextEditingController();
  final _focus = FocusNode();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  // Conserva el estado de validación, los intentos y la cuenta regresiva.
  bool _oculto = true;
  bool _verificado = false;
  bool _error = false;
  int _intentos = 0;
  int _segundos = 40;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicia el plazo de validez mostrado para la verificación.
    _iniciarTimer();
  }

  // Reinicia la cuenta regresiva y detiene cualquier temporizador anterior.
  void _iniciarTimer() {
    _segundos = 40;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundos == 0) {
        t.cancel();
      } else {
        setState(() => _segundos--);
      }
    });
  }

  @override
  void dispose() {
    // Libera el temporizador, el foco y los controladores de entrada.
    _timer?.cancel();
    _codigoCtrl.dispose();
    _focus.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  // Compara el código ingresado y actualiza el estado de validación.
  void _verificar() {
    // TODO: validar código real con Firebase
    if (_codigoCtrl.text == '123456') {
      setState(() {
        _verificado = true;
        _error = false;
      });
    } else {
      setState(() {
        _error = true;
        _intentos++;
      });
    }
  }

  // Dibuja las seis casillas y mantiene un campo oculto para capturar el código.
  Widget _cajasCodigo() {
    final texto = _codigoCtrl.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final lleno = i < texto.length;
              return Container(
                width: 48,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.campo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _error && lleno
                          ? AppColors.rojo.withAlpha(120)
                          : AppColors.borde),
                ),
                child: Text(
                  lleno ? texto[i] : '•',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: lleno
                        ? (_error ? AppColors.rojo : AppColors.verde)
                        : AppColors.gris,
                  ),
                ),
              );
            }),
          ),
          // TextField invisible que captura el teclado
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _codigoCtrl,
                focusNode: _focus,
                maxLength: 6,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _error = false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  // Compone la pantalla de verificación, recuperación y cambio de contraseña.
  Widget build(BuildContext context) {
    // Sustituye una dirección vacía por una etiqueta comprensible para la interfaz.
    final correoMostrar =
        widget.correo.isEmpty ? 'tu correo institucional' : widget.correo;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Verify Security Code',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.tarjeta,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(children: [
                        Icon(Icons.arrow_back, size: 14),
                        SizedBox(width: 6),
                        Text('Volver', style: TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tarjeta,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Paso 2 de 3',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const KampusLogo(subtitulo: 'PORTAL DE SEGURIDAD ACADÉMICA'),
              const SizedBox(height: 16),

              // Banner de error
              if (_error) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.rojoFondo,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.error, color: AppColors.rojo),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Error de Validación de Código',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD6D6))),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      const Text(
                          'El código de seguridad ingresado ha expirado o no coincide con el enviado a tu correo institucional.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFFE9A5AD))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A0F1E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Intento fallido ($_intentos de 3 permitidos)',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFFFB3B3))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Código
              KampusCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Código de Verificación (6 dígitos)',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (_error)
                          const Text('00:00\nExpirado',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.rojo)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(
                      text: 'Ingresa la clave enviada a ',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.gris),
                      children: [
                        TextSpan(
                            text: correoMostrar,
                            style: const TextStyle(
                                color: AppColors.texto,
                                fontWeight: FontWeight.bold)),
                      ],
                    )),
                    const SizedBox(height: 14),
                    _cajasCodigo(),
                    if (_error)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Row(children: [
                          Icon(Icons.cancel_outlined,
                              size: 16, color: AppColors.rojo),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                'Código incorrecto o caducado (duración máx. 10 min)',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.rojo)),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.campo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 18, color: AppColors.gris),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Reenviar disponible en',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.gris)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.verdeOscuro.withAlpha(50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${_segundos}s',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.verde)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _segundos == 0
                          ? () {
                              // TODO: reenviar código
                              setState(_iniciarTimer);
                            }
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.campo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forward_to_inbox,
                                size: 18,
                                color: _segundos == 0
                                    ? AppColors.verde
                                    : AppColors.gris),
                            const SizedBox(width: 8),
                            Text('Reenviar Código de Seguridad',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _segundos == 0
                                        ? AppColors.verde
                                        : AppColors.gris)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Nueva contraseña (bloqueada hasta verificar)
              Opacity(
                opacity: _verificado ? 1 : 0.6,
                child: KampusCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Definir Nueva Contraseña',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Text(_verificado ? 'Desbloqueado' : '🔒 Bloqueado',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.gris)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AbsorbPointer(
                        absorbing: !_verificado,
                        child: Column(
                          children: [
                            KampusField(
                              etiqueta: 'Nueva contraseña',
                              hint: '••••••••••••',
                              icono: Icons.lock_outline,
                              controller: _passCtrl,
                              esPassword: true,
                              oculto: _oculto,
                              onToggleOculto: () =>
                                  setState(() => _oculto = !_oculto),
                            ),
                            const SizedBox(height: 12),
                            KampusField(
                              etiqueta: 'Confirmar contraseña',
                              hint: 'Confirmar contraseña',
                              icono: Icons.lock_outline,
                              controller: _pass2Ctrl,
                              esPassword: true,
                              oculto: _oculto,
                              onToggleOculto: () =>
                                  setState(() => _oculto = !_oculto),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                          'Debes verificar el código de 6 dígitos antes de actualizar tus credenciales.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.gris)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                texto: _verificado
                    ? 'Actualizar Contraseña'
                    : (_error ? 'Verificar Código de Nuevo' : 'Verificar Código'),
                icono: _verificado ? Icons.check : Icons.refresh,
                onPressed: _verificado
                    ? () {
                        // TODO: confirmPasswordReset en Firebase
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ResetSuccessPage(
                                  correo: widget.correo)),
                        );
                      }
                    : (_codigoCtrl.text.length == 6 ? _verificar : null),
              ),
              const SizedBox(height: 16),
              const InfoBox(
                icono: Icons.help_outline,
                texto:
                    '¿No recibiste ningún correo? Revisa tu carpeta de spam, correo no deseado o promociones institucionales. Si el problema persiste, contacta directamente con soporte.',
              ),
              const SizedBox(height: 14),
              const Text('Contactar Soporte Técnico / Mesa de Ayuda',
                  style: TextStyle(fontSize: 12, color: AppColors.verde)),
              const SizedBox(height: 6),
              if (_error)
                const Text('ID Incidencia: #SEC-98214-ERR',
                    style: TextStyle(fontSize: 11, color: AppColors.gris)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
