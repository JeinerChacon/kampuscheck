import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import '../src/kampus_widgets.dart';
import '../src/validadores.dart';
import 'auth_gate.dart';

/// Código que entrega la institución a los agentes de la Mesa de Ayuda.
/// Cámbialo por el tuyo. (La protección real está en las reglas de Firestore.)
const String codigoAgenteSoporte = 'KAMPUS-SOPORTE-2026';

/// Registro breve para agentes de soporte: nombre, correo, clave y código.
class RegistroSoportePage extends StatefulWidget {
  const RegistroSoportePage({super.key});

  @override
  State<RegistroSoportePage> createState() => _RegistroSoportePageState();
}

class _RegistroSoportePageState extends State<RegistroSoportePage> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _pass = TextEditingController();
  final _codigo = TextEditingController();
  bool _oculto = true;
  bool _cargando = false;
  String? _errNombre, _errCorreo, _errPass, _errCodigo, _errGeneral;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _pass, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() {
      _errGeneral = null;
      _errNombre = _nombre.text.trim().isEmpty ? 'Ingresa tu nombre.' : null;
      _errCorreo = esCorreoPermitido(_correo.text) ? null : mensajeCorreoInvalido;
      _errPass = _pass.text.length >= 8 ? null : 'Mínimo 8 caracteres.';
      _errCodigo = _codigo.text.trim() == codigoAgenteSoporte ? null : 'Código de agente incorrecto.';
    });
    if ([_errNombre, _errCorreo, _errPass, _errCodigo].any((e) => e != null)) return;

    setState(() => _cargando = true);
    try {
      final perfil = await AuthProvider.registrar(
        rol: 'soporte',
        nombre: _nombre.text,
        correo: _correo.text,
        password: _pass.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => panelPorRol(perfil)),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errGeneral = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Soporte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: KampusCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Agente de Mesa de Ayuda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Registro rápido: solo lo necesario para atender tickets.', style: TextStyle(fontSize: 13, color: AppColors.gris)),
              const SizedBox(height: 16),
              KampusField(
                etiqueta: 'Nombre',
                hint: 'Tu nombre completo',
                icono: Icons.person_outline,
                controller: _nombre,
                error: _errNombre,
                onChanged: (_) => setState(() => _errNombre = null),
              ),
              const SizedBox(height: 14),
              KampusField(
                etiqueta: 'Correo',
                hint: 'agente@udla.edu.co',
                icono: Icons.alternate_email,
                controller: _correo,
                teclado: TextInputType.emailAddress,
                error: _errCorreo,
                onChanged: (_) => setState(() => _errCorreo = null),
              ),
              const SizedBox(height: 14),
              KampusField(
                etiqueta: 'Contraseña',
                hint: 'Mínimo 8 caracteres',
                icono: Icons.lock_outline,
                controller: _pass,
                esPassword: true,
                oculto: _oculto,
                onToggleOculto: () => setState(() => _oculto = !_oculto),
                error: _errPass,
                onChanged: (_) => setState(() => _errPass = null),
              ),
              const SizedBox(height: 14),
              KampusField(
                etiqueta: 'Código de agente',
                hint: 'Lo entrega la institución',
                icono: Icons.vpn_key_outlined,
                controller: _codigo,
                error: _errCodigo,
                onChanged: (_) => setState(() => _errCodigo = null),
              ),
              if (_errGeneral != null) ...[
                const SizedBox(height: 12),
                Text(_errGeneral!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              PrimaryButton(texto: 'Crear cuenta de Soporte', cargando: _cargando, onPressed: _registrar),
            ]),
          ),
        ),
      ),
    );
  }
}