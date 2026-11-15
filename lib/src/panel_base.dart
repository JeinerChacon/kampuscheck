import 'dart:async'; // Proporciona la suscripción al flujo de autenticación.
import 'package:flutter/material.dart'; // Proporciona los widgets de interfaz y navegación.
import '../page/login_page.dart'; // Importa la pantalla de acceso para cerrar la sesión visualmente.
import '../providers/auth_provider.dart'; // Importa las operaciones de autenticación de la aplicación.
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User; // Permite observar los cambios de usuario autenticado.
import 'app_theme.dart'; // Importa los colores compartidos del tema.
import 'kampus_widgets.dart'; // Importa los componentes reutilizables de la interfaz.

/// Panel base: guardia de sesión + bloqueo del botón "atrás".
/// - Sin [cuerpo]: muestra saludo + botón "Cerrar sesión" (panel estudiante).
/// - Con [cuerpo]: muestra ese contenido y el cierre de sesión va en el AppBar.
class PanelBase extends StatefulWidget {
  final String titulo; // Guarda el título de la barra superior.
  final IconData icono; // Guarda el icono del panel sin contenido personalizado.
  final String saludo; // Guarda el saludo mostrado en el panel básico.
  final String detalle; // Guarda el texto complementario del saludo.
  final Widget? cuerpo; // Permite proporcionar contenido personalizado.
  final Widget? fab; // Permite proporcionar un botón flotante.
  final Widget? bottomNav; // Permite proporcionar navegación inferior.
  final List<Widget>? acciones; // Permite reemplazar las acciones predeterminadas de la barra.

  // Recibe los datos comunes y las partes opcionales del panel.
  const PanelBase({
    super.key,
    required this.titulo,
    required this.icono,
    required this.saludo,
    required this.detalle,
    this.cuerpo,
    this.fab,
    this.bottomNav,
    this.acciones,
  });

  @override
  State<PanelBase> createState() => _PanelBaseState();
}

class _PanelBaseState extends State<PanelBase> {
  StreamSubscription<User?>? _sub; // Conserva la suscripción a cambios de autenticación.
  bool _saliendo = false; // Evita iniciar más de una navegación al cerrar sesión.

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) { // Observa el estado de autenticación de Firebase.
      if (user == null) _irAlLogin(); // Regresa al acceso cuando no queda un usuario autenticado.
    });
  }

  // Elimina la pantalla protegida y regresa al inicio de sesión.
  void _irAlLogin() {
    if (_saliendo || !mounted) return; // Evita navegar repetidamente o desde un widget desmontado.
    _saliendo = true; // Marca que la navegación de salida ya comenzó.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()), // Crea la pantalla de acceso de destino.
      (route) => false, // Elimina las rutas anteriores de la pila de navegación.
    );
  }

  @override
  void dispose() {
    _sub?.cancel(); // Libera la suscripción para evitar notificaciones posteriores.
    super.dispose();
  }

  @override
  // Construye el panel y adapta su presentación a la existencia de contenido propio.
  Widget build(BuildContext context) {
    final conCuerpo = widget.cuerpo != null; // Determina si se proporcionó contenido personalizado.
    return PopScope(
      canPop: false, // Impide cerrar el panel con la navegación hacia atrás.
      child: Scaffold(
        floatingActionButton: widget.fab, // Muestra el botón flotante opcional.
        bottomNavigationBar: widget.bottomNav, // Muestra la barra de navegación inferior opcional.
        appBar: AppBar(
          automaticallyImplyLeading: false, // Evita agregar automáticamente un botón de regreso.
          title: Text(widget.titulo,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          actions: widget.acciones ?? // Usa las acciones recibidas o las acciones predeterminadas.
              (conCuerpo
                  ? [
                      IconButton(
                        tooltip: 'Cerrar sesión', // Describe la acción del botón.
                        icon: const Icon(Icons.logout), // Representa visualmente el cierre de sesión.
                        onPressed: () => AuthProvider.cerrarSesion(), // Solicita terminar la sesión actual.
                      ),
                    ]
                  : null),
        ),
        body: SafeArea( // Mantiene el contenido fuera de las áreas reservadas del dispositivo.
          child: conCuerpo // Elige el contenido personalizado o el panel básico.
              ? widget.cuerpo!
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.verde.withAlpha(30),
                          ),
                          child: Icon(widget.icono,
                              size: 44, color: AppColors.verde),
                        ),
                        const SizedBox(height: 20),
                        Text(widget.saludo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(widget.detalle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.gris)),
                        const SizedBox(height: 32),
                        PrimaryButton(
                          texto: 'Cerrar sesión', // Etiqueta el botón de salida.
                          icono: Icons.logout, // Muestra el icono de cierre de sesión.
                          onPressed: () => AuthProvider.cerrarSesion(), // Solicita cerrar la sesión.
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
