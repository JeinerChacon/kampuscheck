import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../src/app_theme.dart';
import 'docente_panel_page.dart';
import 'estudiante/estudiante_panel_page.dart';
import 'login_page.dart';
import 'soporte/soporte_panel_page.dart';

/// Devuelve el panel que corresponde al rol del perfil.
Widget panelPorRol(Map<String, dynamic> perfil) {
  return switch (perfil['rol']) {
    'docente' => DocentePanelPage(perfil: perfil),
    'soporte' => SoportePanelPage(perfil: perfil),
    _ => EstudiantePanelPage(perfil: perfil),
  };
}

/// Pantalla inicial: si ya hay sesión guardada entra directo a su panel,
/// si no, muestra el login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Map<String, dynamic>?> _perfilInicial;

  @override
  void initState() {
    super.initState();
    _perfilInicial = AuthProvider.perfilActual();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _perfilInicial,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.verde),
            ),
          );
        }
        final perfil = snapshot.data;
        return perfil == null ? const LoginPage() : panelPorRol(perfil);
      },
    );
  }
}