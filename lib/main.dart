import 'package:flutter/material.dart'; // Proporciona los componentes de interfaz de Flutter.
import 'package:firebase_core/firebase_core.dart'; // Permite inicializar Firebase.
import 'page/auth_gate.dart'; // Importa la pantalla que decide el acceso según la sesión.
import 'src/app_theme.dart'; // Importa el tema visual compartido.
import 'firebase_options.dart'; // Importa la configuración Firebase de cada plataforma.

// Punto de entrada asíncrono que prepara Firebase antes de mostrar la aplicación.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Prepara los servicios de Flutter antes de usar plugins.
  await Firebase.initializeApp( // Inicializa Firebase con las credenciales de la plataforma actual.
    options: DefaultFirebaseOptions.currentPlatform, // Selecciona la configuración específica de la plataforma.
  );
  runApp(const KampusCheckApp()); // Monta la aplicación raíz en la pantalla.
}

// Widget raíz que configura la apariencia y la pantalla inicial de KampusCheck.
class KampusCheckApp extends StatelessWidget {
  const KampusCheckApp({super.key}); // Permite crear el widget inmutable con una clave opcional.

  @override
  // Construye la configuración global de la aplicación.
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KampusCheck', // Define el nombre de la aplicación.
      debugShowCheckedModeBanner: false, // Oculta la marca de depuración de Flutter.
      theme: AppTheme.oscuro, // Aplica el tema oscuro compartido.
      home: const AuthGate(), // Muestra la pantalla de control de autenticación al iniciar.
    );
  }
}