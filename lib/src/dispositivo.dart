import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Identificador único de esta instalación de la app (se crea una vez y se
/// guarda). Sirve para impedir que un mismo teléfono registre asistencia con
/// varias cuentas en la misma clase.
Future<String> idDispositivo() async {
  final p = await SharedPreferences.getInstance();
  var id = p.getString('kampus_device_id');
  if (id == null || id.isEmpty) {
    final r = Random.secure();
    id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
    await p.setString('kampus_device_id', id);
  }
  return id;
}