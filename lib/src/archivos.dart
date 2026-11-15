import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class ArchivoTexto {
  final String nombre;
  final int bytes;
  final String texto;
  const ArchivoTexto(this.nombre, this.bytes, this.texto);
}

/// Abre el selector del sistema y devuelve el contenido de un .csv/.txt.
Future<ArchivoTexto?> elegirArchivoTexto() async {
  final archivos = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'txt'],
  );
  if (archivos.isEmpty) return null;
  final f = archivos.first;
  final datos = await f.readAsBytes();
  var texto = utf8.decode(datos, allowMalformed: true);
  if (texto.contains('\uFFFD')) {
    texto = latin1.decode(datos); // CSV "ANSI" de Excel
  }
  if (texto.startsWith('\uFEFF')) texto = texto.substring(1);
  return ArchivoTexto(f.name, datos.length, texto);
}

/// Guarda un archivo de texto con el diálogo "Guardar como". true si se guardó.
Future<bool> guardarArchivoTexto(
  String nombre,
  String contenido, {
  String mimeType = 'text/csv',
  bool bom = true,
}) async {
  // BOM para que Excel respete tildes y eñes (solo CSV).
  final datos = Uint8List.fromList([
    if (bom) ...[0xEF, 0xBB, 0xBF],
    ...utf8.encode(contenido),
  ]);
  final ruta = await FilePicker.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: nombre,
    bytes: datos,
    mimeType: mimeType,
  );
  return ruta != null;
}

class ArchivoBinario {
  final String nombre;
  final Uint8List bytes;
  const ArchivoBinario(this.nombre, this.bytes);
}

/// Selector de soporte para justificaciones (pdf / imagen). Máx. ~700 KB.
Future<ArchivoBinario?> elegirAdjunto() async {
  final archivos = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
  );
  if (archivos.isEmpty) return null;
  final f = archivos.first;
  return ArchivoBinario(f.name, await f.readAsBytes());
}

/// Guarda bytes con el diálogo "Guardar como" (descargar adjunto).
Future<bool> guardarArchivoBytes(String nombre, Uint8List bytes) async {
  final ruta = await FilePicker.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: nombre,
    bytes: bytes,
  );
  return ruta != null;
}