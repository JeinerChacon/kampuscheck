// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kampuscheck/page/login_page.dart';
import 'package:kampuscheck/src/app_theme.dart';

// Agrupa las pruebas de widgets del proyecto.
void main() {
  // Comprueba que la pantalla de acceso presente sus campos y opción de sesión.
  testWidgets('La pantalla de acceso muestra los campos institucionales', (
    WidgetTester tester,
  ) async {
    // Monta la pantalla de acceso dentro de la aplicación de prueba.
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.oscuro, home: const LoginPage()),
    );

    // Verifica que el campo para correo institucional esté visible una vez.
    expect(find.text('Correo Institucional'), findsOneWidget);
    // Verifica que el campo para contraseña esté visible una vez.
    expect(find.text('Contraseña'), findsOneWidget);
    // Verifica que la opción para recordar la sesión esté visible una vez.
    expect(find.text('Recordar sesión en este dispositivo'), findsOneWidget);
  });
}
