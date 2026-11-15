import 'package:flutter/material.dart';

// Centraliza los colores usados por los componentes de la interfaz.
class AppColors {
  static const Color fondo = Color(0xFF0A1020); // Define el fondo oscuro general.
  static const Color tarjeta = Color(0xFF131B2E); // Define el fondo de tarjetas y superficies.
  static const Color campo = Color(0xFF0E1526); // Define el fondo de campos de entrada.
  static const Color borde = Color(0xFF1F2A44); // Define el color de bordes y elementos inactivos.
  static const Color verde = Color(0xFF3DDC97); // Define el verde principal de énfasis.
  static const Color verdeOscuro = Color(0xFF10B981); // Define el verde oscuro para estados activos.
  static const Color texto = Color(0xFFE6EAF2); // Define el color principal del texto.
  static const Color gris = Color(0xFF8A94AA); // Define el color secundario de texto e iconos.
  static const Color rojo = Color(0xFFEF6B6B); // Define el color de errores.
  static const Color rojoFondo = Color(0xFF3A0F18); // Define el fondo que acompaña los errores.
}

// Agrupa la configuración visual compartida de la aplicación.
class AppTheme {
  // Construye el tema oscuro utilizado por la interfaz.
  static ThemeData get oscuro => ThemeData(
        brightness: Brightness.dark, // Selecciona una paleta de brillo oscuro.
        scaffoldBackgroundColor: AppColors.fondo, // Aplica el fondo general a las pantallas.
        fontFamily: 'Roboto', // Define la tipografía base de la aplicación.
        colorScheme: const ColorScheme.dark(
          primary: AppColors.verde, // Establece el color primario del esquema.
          surface: AppColors.tarjeta, // Establece el color de las superficies.
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.fondo, // Integra la barra superior con el fondo.
          elevation: 0, // Elimina la sombra de la barra superior.
          centerTitle: true, // Centra el título de la barra.
        ),
      );
}
