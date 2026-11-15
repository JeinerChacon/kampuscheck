import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../providers/soporte_provider.dart';
import '../../src/app_theme.dart';
import '../../src/kampus_widgets.dart';
import '../../src/panel_base.dart';
import 'soporte_chat_page.dart';

/// Panel del agente de soporte (usuario con rol "soporte"):
/// bandeja de tickets y perfil.
class SoportePanelPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const SoportePanelPage({super.key, required this.perfil});

  @override
  State<SoportePanelPage> createState() => _SoportePanelPageState();
}

class _SoportePanelPageState extends State<SoportePanelPage> {
  int _tab = 0;
  bool _abiertos = true;

  String _cuando(Timestamp? t) {
    final d = t?.toDate();
    if (d == null) return '';
    final ahora = DateTime.now();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final hora = '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    final hoy = d.year == ahora.year && d.month == ahora.month && d.day == ahora.day;
    return hoy ? hora : '${d.day}/${d.month} $hora';
  }

  Widget _bandeja() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SoporteProvider.tickets(abiertos: _abiertos),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar los tickets.\nVerifica que tu usuario tenga rol "soporte" y que las reglas de Firestore estén publicadas.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.rojo, fontSize: 12),
              ),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.verde));
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final x = (a.data()['ultimoEn'] as Timestamp?)?.toDate() ?? DateTime.now();
            final y = (b.data()['ultimoEn'] as Timestamp?)?.toDate() ?? DateTime.now();
            return y.compareTo(x); // más recientes primero
          });
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Bandeja de Soporte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Atiende los tickets de estudiantes y docentes', style: TextStyle(fontSize: 12, color: AppColors.gris)),
          const SizedBox(height: 14),
          Row(children: [
            for (final f in [(true, 'Abiertos'), (false, 'Cerrados')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(f.$2), selected: _abiertos == f.$1, onSelected: (_) => setState(() => _abiertos = f.$1)),
              ),
          ]),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            InfoBox(icono: Icons.inbox_outlined, texto: _abiertos ? 'No hay tickets abiertos. ¡Todo al día!' : 'Aún no hay tickets cerrados.'),
          for (final d in docs)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SoporteChatPage(perfil: widget.perfil, ticketId: d.id, comoSoporte: true)),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borde)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('#${SoporteProvider.numero(d.id)}', style: const TextStyle(fontSize: 12, color: AppColors.verde, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.campo, borderRadius: BorderRadius.circular(8)),
                      child: Text('${d.data()['rol'] ?? ''}', style: const TextStyle(fontSize: 10, color: AppColors.gris)),
                    ),
                    const Spacer(),
                    Text(_cuando(d.data()['ultimoEn'] as Timestamp?), style: const TextStyle(fontSize: 10, color: AppColors.gris, fontFamily: 'monospace')),
                  ]),
                  const SizedBox(height: 6),
                  Text('${d.data()['nombre']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${d.data()['ultimoMensaje'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.gris)),
                  if ('${d.data()['agenteNombre'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Atiende: ${d.data()['agenteNombre']}', style: const TextStyle(fontSize: 11, color: AppColors.verde)),
                  ],
                ]),
              ),
            ),
        ]);
      },
    );
  }

  Widget _perfil() {
    final p = widget.perfil;
    return ListView(padding: const EdgeInsets.all(16), children: [
      KampusCard(
        child: Column(children: [
          const CircleAvatar(radius: 40, backgroundColor: AppColors.campo, child: Icon(Icons.support_agent, size: 38, color: AppColors.verde)),
          const SizedBox(height: 12),
          Text('${p['nombre'] ?? 'Agente'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('${p['correo'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          const SizedBox(height: 10),
          const Text('Agente de soporte', style: TextStyle(fontSize: 13, color: AppColors.verde, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 16),
      PrimaryButton(texto: 'Cerrar sesión', icono: Icons.logout, onPressed: () => AuthProvider.cerrarSesion()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PanelBase(
      titulo: 'KampusCheck',
      icono: Icons.support_agent,
      saludo: 'Hola, ${widget.perfil['nombre'] ?? 'Agente'}',
      detalle: 'Soporte',
      acciones: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${widget.perfil['nombre'] ?? 'Agente'}'.split(' ').take(2).join(' '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const Text('Soporte', style: TextStyle(fontSize: 10, color: AppColors.gris)),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 10, right: 16),
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
          child: const Icon(Icons.person_outline, size: 18, color: Colors.black),
        ),
      ],
      cuerpo: IndexedStack(index: _tab, children: [_bandeja(), _perfil()]),
      bottomNav: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: AppColors.tarjeta,
        selectedItemColor: AppColors.verde,
        unselectedItemColor: AppColors.gris,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Tickets'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}