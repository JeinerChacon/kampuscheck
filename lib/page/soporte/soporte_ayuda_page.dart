import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/soporte_provider.dart';
import '../../src/app_theme.dart';
import '../../src/kampus_widgets.dart';
import 'soporte_chat_page.dart';

/// Mesa de ayuda: chat, correo y preguntas frecuentes.
/// [perfil] es null cuando se abre desde el login (aún sin sesión).
class SoporteAyudaPage extends StatelessWidget {
  final Map<String, dynamic>? perfil;
  const SoporteAyudaPage({super.key, this.perfil});

  void _aviso(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  void _chat(BuildContext context) {
    if (perfil == null) {
      // Sin sesión (ej. no puede iniciar sesión): formulario de contacto.
      showDialog<void>(context: context, builder: (_) => const _DialogoInvitado());
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => SoporteChatPage(perfil: perfil!)));
  }

  Widget _tarjeta({required IconData icono, required String titulo, required String sub, required Widget pie}) =>
      KampusCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(14)),
              child: Icon(icono, color: AppColors.verde),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.gris, fontFamily: 'monospace')),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          pie,
        ]),
      );

  Widget _faq(String pregunta, String respuesta) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        // Material (no Container con color): evita el aviso de ListTile en consola.
        child: Material(
          color: AppColors.campo,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Theme(
          data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            iconColor: AppColors.gris,
            collapsedIconColor: AppColors.gris,
            title: Text(pregunta, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.texto)),
            children: [Align(alignment: Alignment.centerLeft, child: Text(respuesta, style: const TextStyle(fontSize: 12, color: AppColors.gris, height: 1.4)))],
          ),
        ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final conSesion = perfil != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Helpdesk Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(conSesion ? 'Volver' : 'Volver al Login'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(20)),
              child: const Text('● SOPORTE Y MESA DE AYUDA', style: TextStyle(fontSize: 10, color: AppColors.verde, fontFamily: 'monospace')),
            ),
          ]),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.verified_user_outlined, size: 38, color: AppColors.verde),
            ),
          ),
          const SizedBox(height: 10),
          const Center(child: Text('KAMPUSCHECK', style: TextStyle(fontSize: 12, color: AppColors.verde, fontFamily: 'monospace', letterSpacing: 1.5))),
          const SizedBox(height: 6),
          const Text('¿Necesitas ayuda con tu cuenta?', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Comunícate directamente con el equipo de soporte técnico institucional de KampusCheck.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.gris)),
          const SizedBox(height: 20),
          _tarjeta(
            icono: Icons.chat_bubble_outline,
            titulo: 'Chat de Soporte Rápido',
            sub: 'Abre un ticket con un agente',
            pie: Row(children: [
              const Expanded(child: Text('Atención: Lun a Vie 7am - 8pm', style: TextStyle(fontSize: 12, color: AppColors.verde, fontFamily: 'monospace'))),
              GestureDetector(
                onTap: () => _chat(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.verde, borderRadius: BorderRadius.circular(24)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Iniciar Chat', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.north_east, size: 16, color: Colors.black),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _tarjeta(
            icono: Icons.mail_outline,
            titulo: 'Correo de Soporte Técnico',
            sub: SoporteProvider.correo,
            pie: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: SoporteProvider.correo));
                  _aviso(context, 'Correo copiado');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(24)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy, size: 16),
                    SizedBox(width: 6),
                    Text('Copiar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: 'Para: ${SoporteProvider.correo}\nAsunto: Soporte KampusCheck'));
                  _aviso(context, 'Destinatario y asunto copiados. Pégalos en tu app de correo.');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.verde, borderRadius: BorderRadius.circular(24)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Redactar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.send, size: 15, color: Colors.black),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          KampusCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.help_outline, color: AppColors.verde, size: 20),
                SizedBox(width: 8),
                Text('Preguntas Frecuentes Rápidas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              _faq('¿Cómo desbloquear mi correo institucional?', 'Tras varios intentos fallidos la cuenta se bloquea por seguridad. Usa "¿Olvidaste tu contraseña?" en el login o escribe a soporte indicando tu matrícula o código de empleado.'),
              _faq('¿Por qué no llega el código de verificación?', 'Revisa la carpeta de spam y confirma que tu correo esté bien escrito. Algunas facultades filtran los correos nuevos; si pasan 10 minutos, abre un ticket de chat.'),
              _faq('¿Por qué mi asistencia sale "fuera de rango"?', 'Debes estar dentro del radio que configuró el docente. Activa el GPS en alta precisión, acércate al aula y pulsa "Actualizar mi ubicación".'),
              _faq('¿Cómo justifico una inasistencia?', 'Desde "Marcar Asistencia" o desde Perfil → Justificar Inasistencias. Tu docente recibirá la solicitud y podrá aprobarla.'),
            ]),
          ),
          const SizedBox(height: 18),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.apartment, size: 16, color: AppColors.gris),
            SizedBox(width: 8),
            Flexible(
              child: Text('Mesa de Ayuda de TI • Campus Central • Edificio de Tecnologías Piso 1',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.gris, fontFamily: 'monospace')),
            ),
          ]),
        ]),
      ),
    );
  }
}
/// Formulario para escribir a soporte sin haber iniciado sesión.
class _DialogoInvitado extends StatefulWidget {
  const _DialogoInvitado();

  @override
  State<_DialogoInvitado> createState() => _DialogoInvitadoState();
}

class _DialogoInvitadoState extends State<_DialogoInvitado> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _texto = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await SoporteProvider.enviarInvitado(
        nombre: _nombre.text,
        correo: _correo.text,
        texto: _texto.text,
      );
      if (!mounted) return;
      final msg = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      msg.showSnackBar(const SnackBar(
        content: Text('Mensaje enviado. Un agente te responderá a tu correo.'),
      ));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Escribe a soporte'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'No necesitas iniciar sesión. Déjanos tus datos y un agente te responderá por correo.',
              style: TextStyle(fontSize: 12, color: AppColors.gris),
            ),
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Tu nombre')),
            TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo de contacto'),
            ),
            TextField(
              controller: _texto,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(labelText: '¿Qué problema tienes?', errorText: _error),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: _enviando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: _enviando ? null : _enviar, child: Text(_enviando ? 'Enviando…' : 'Enviar')),
        ],
      );
}