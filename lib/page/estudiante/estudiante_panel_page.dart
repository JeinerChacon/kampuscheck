import 'package:flutter/material.dart';
import '../../providers/estudiante_provider.dart';
import '../../src/app_theme.dart';
import '../../src/panel_base.dart';
import 'estudiante_cursos.dart';
import 'estudiante_dashboard.dart';
import 'estudiante_horario.dart';
import 'estudiante_perfil.dart';

/// Panel del estudiante: Dashboard · Cursos · Horario · Perfil.
/// Los datos se cargan una sola vez aquí y se comparten con las pestañas.
class EstudiantePanelPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const EstudiantePanelPage({super.key, required this.perfil});

  @override
  State<EstudiantePanelPage> createState() => _EstudiantePanelPageState();
}

class _EstudiantePanelPageState extends State<EstudiantePanelPage> {
  int _tab = 0;
  late Future<Map<String, dynamic>> _datos = EstudianteProvider.cargar(widget.perfil);

  Future<void> _recargar() async {
    setState(() {
      _datos = EstudianteProvider.cargar(widget.perfil);
    });
    await _datos.catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${widget.perfil['nombre'] ?? 'Estudiante'}'.split(' ').take(2).join(' ');
    return PanelBase(
      titulo: 'KampusCheck',
      icono: Icons.school,
      saludo: 'Hola, ${widget.perfil['nombre'] ?? 'Estudiante'}',
      detalle: 'Matrícula: ${widget.perfil['matricula'] ?? '---'}',
      acciones: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const Text('Estudiante', style: TextStyle(fontSize: 10, color: AppColors.gris)),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() => _tab = 3),
          child: Container(
            margin: const EdgeInsets.only(left: 10, right: 16),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline, size: 18, color: Colors.black),
          ),
        ),
      ],
      // IndexedStack mantiene vivas las pestañas (no recarga al cambiar).
      cuerpo: IndexedStack(index: _tab, children: [
        EstudianteDashboard(perfil: widget.perfil, datos: _datos, onRecargar: _recargar),
        EstudianteCursos(datos: _datos, onRecargar: _recargar),
        EstudianteHorario(datos: _datos, onRecargar: _recargar),
        EstudiantePerfil(perfil: widget.perfil, datos: _datos),
      ]),
      bottomNav: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.tarjeta,
        selectedItemColor: AppColors.verde,
        unselectedItemColor: AppColors.gris,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.school_outlined), label: 'Cursos'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Horario'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}