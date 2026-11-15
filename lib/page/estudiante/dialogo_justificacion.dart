import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../providers/estudiante_provider.dart';
import '../../src/app_theme.dart';
import '../../src/archivos.dart';

/// Resultado del diálogo de justificación.
class DatosJustificacion {
  final int indice; // falta elegida (0 si no hay lista)
  final String motivo;
  final String? archivoNombre;
  final Uint8List? archivo;
  const DatosJustificacion(this.indice, this.motivo, this.archivoNombre, this.archivo);
}

/// Justificación de UNA inasistencia: motivo breve + archivo opcional.
/// [faltas] = lista de inasistencias para elegir (null = sesión ya definida).
Future<DatosJustificacion?> pedirJustificacion(
  BuildContext context, {
  List<String>? faltas,
  String? detalle,
}) =>
    showDialog<DatosJustificacion>(
      context: context,
      builder: (_) => _DialogoJustificacion(faltas: faltas, detalle: detalle),
    );

class _DialogoJustificacion extends StatefulWidget {
  final List<String>? faltas;
  final String? detalle;
  const _DialogoJustificacion({this.faltas, this.detalle});

  @override
  State<_DialogoJustificacion> createState() => _DialogoJustificacionState();
}

class _DialogoJustificacionState extends State<_DialogoJustificacion> {
  final _motivo = TextEditingController();
  int _idx = 0;
  String? _error;
  ArchivoBinario? _adjunto;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
    try {
      final a = await elegirAdjunto();
      if (a == null) return;
      if (a.bytes.length > EstudianteProvider.maxAdjuntoBytes) {
        setState(() => _error = 'El archivo supera 700 KB.');
        return;
      }
      setState(() {
        _adjunto = a;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'No se pudo abrir el archivo.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Justificar inasistencia'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.detalle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(widget.detalle!, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              ),
            if (widget.faltas != null) ...[
              DropdownButtonFormField<int>(
                initialValue: _idx,
                isExpanded: true,
                dropdownColor: AppColors.tarjeta,
                decoration: const InputDecoration(labelText: 'Clase en la que faltaste'),
                items: [
                  for (var i = 0; i < widget.faltas!.length; i++)
                    DropdownMenuItem(value: i, child: Text(widget.faltas![i], overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _idx = v ?? 0),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _motivo,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(labelText: 'Motivo o descripción breve', errorText: _error),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _elegir,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(
                  _adjunto == null ? 'Adjuntar archivo (PDF / imagen)' : _adjunto!.nombre,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (_motivo.text.trim().length < 5) {
                setState(() => _error = 'Cuéntale al docente qué pasó (mínimo 5 letras).');
                return;
              }
              Navigator.pop(
                context,
                DatosJustificacion(_idx, _motivo.text.trim(), _adjunto?.nombre, _adjunto?.bytes),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      );
}