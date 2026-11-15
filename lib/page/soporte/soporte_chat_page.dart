import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../providers/soporte_provider.dart';
import '../../src/app_theme.dart';

/// Chat de soporte. Lo usa el usuario (crea / retoma su ticket) y el agente
/// ([comoSoporte] = true, con el [ticketId] elegido en su lista).
class SoporteChatPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final String? ticketId;
  final bool comoSoporte;
  const SoporteChatPage({super.key, required this.perfil, this.ticketId, this.comoSoporte = false});

  @override
  State<SoporteChatPage> createState() => _SoporteChatPageState();
}

class _SoporteChatPageState extends State<SoporteChatPage> {
  static const _sugeridas = [
    ('No recibo el código', Icons.north_east),
    ('Fallo geolocalización (10m)', Icons.near_me_outlined),
    ('Desbloquear cuenta', Icons.vpn_key_outlined),
    ('Error al marcar asistencia', Icons.error_outline),
  ];

  final _texto = TextEditingController();
  final _scroll = ScrollController();
  String? _ticketId;
  bool _cargando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _ticketId = widget.ticketId;
    _cargar();
  }

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_ticketId == null && !widget.comoSoporte) {
      try {
        _ticketId = await SoporteProvider.ticketAbiertoDe(widget.perfil['uid'] as String);
      } on AuthException catch (e) {
        _aviso(e.mensaje);
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _aviso(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _enviar([String? rapido]) async {
    final t = (rapido ?? _texto.text).trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _texto.clear();
    try {
      final id = await SoporteProvider.enviar(
        perfil: widget.perfil,
        ticketId: _ticketId,
        texto: t,
        comoSoporte: widget.comoSoporte,
      );
      if (mounted) setState(() => _ticketId = id);
    } on AuthException catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cerrar() async {
    final id = _ticketId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.tarjeta,
        title: const Text('Cerrar ticket'),
        content: const Text('¿El problema quedó resuelto? Podrás abrir uno nuevo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar ticket')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SoporteProvider.cerrar(id);
    } on AuthException catch (e) {
      _aviso(e.mensaje);
    }
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String _hora(Timestamp? t) {
    final d = t?.toDate();
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  // ───────────────────────── piezas ─────────────────────────
  Widget _cabecera(Map<String, dynamic>? t) {
    final agente = '${t?['agenteNombre'] ?? ''}'.trim();
    final titulo = widget.comoSoporte ? '${t?['nombre'] ?? 'Usuario'}' : 'Soporte Kampuscheck';
    final sub = widget.comoSoporte ? '${t?['correo'] ?? ''}' : 'Mesa de ayuda';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16)),
            child: Icon(widget.comoSoporte ? Icons.person_outline : Icons.support_agent, color: AppColors.verde, size: 26),
          ),
          Positioned(right: 0, bottom: 0, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: AppColors.verde, shape: BoxShape.circle, border: Border.all(color: AppColors.tarjeta, width: 2)))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.comoSoporte ? sub : (agente.isEmpty ? '● Mesa de ayuda' : '● Atiende $agente'),
                style: const TextStyle(fontSize: 11, color: AppColors.verde)),
          ]),
        ),
        if (_ticketId != null && (t?['estado'] ?? 'abierto') == 'abierto')
          PopupMenuButton<String>(
            color: AppColors.tarjeta,
            onSelected: (_) => _cerrar(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'cerrar', child: Text('Cerrar ticket'))],
          ),
      ]),
    );
  }

  Widget _tarjetaTicket(Map<String, dynamic>? t) {
    final cerrado = t?['estado'] == 'cerrado';
    final agente = '${t?['agenteNombre'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borde)),
      child: Row(children: [
        Icon(Icons.circle, size: 9, color: cerrado ? AppColors.gris : AppColors.verde),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _ticketId == null ? 'Nuevo ticket' : '${cerrado ? 'Ticket cerrado' : 'Ticket activo'} #${SoporteProvider.numero(_ticketId!)}',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: cerrado ? AppColors.gris : AppColors.verde),
            ),
            const SizedBox(height: 2),
            Text(
              _ticketId == null
                  ? 'Se crea al enviar tu primer mensaje'
                  : (agente.isEmpty ? 'Esperando a un agente de soporte' : 'Atiende: $agente'),
              style: const TextStyle(fontSize: 13, color: AppColors.texto),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _burbuja(Map<String, dynamic> m) {
    final mio = m['de'] == widget.perfil['uid'];
    final soporte = m['rol'] == 'soporte';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: mio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mio) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.tarjeta, shape: BoxShape.circle),
              child: Icon(soporte ? Icons.support_agent : Icons.person_outline, size: 18, color: AppColors.verde),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(crossAxisAlignment: mio ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: mio ? const Color(0xFF0FB57A) : AppColors.tarjeta,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mio ? 18 : 4),
                    bottomRight: Radius.circular(mio ? 4 : 18),
                  ),
                ),
                child: Text('${m['texto']}', style: TextStyle(fontSize: 15, height: 1.35, color: mio ? Colors.black : AppColors.texto)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_hora(m['creadoEn'] as Timestamp?), style: const TextStyle(fontSize: 10, color: AppColors.gris, fontFamily: 'monospace')),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _lista(Map<String, dynamic>? t) {
    final cerrado = t?['estado'] == 'cerrado';
    if (_ticketId == null) {
      return ListView(controller: _scroll, padding: const EdgeInsets.all(14), children: [_banner(), _sugerencias()]);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SoporteProvider.mensajes(_ticketId!),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('No se pudo cargar el chat.', style: TextStyle(color: AppColors.rojo)));
        }
        final docs = snap.data?.docs ?? [];
        _irAlFinal();
        return ListView(controller: _scroll, padding: const EdgeInsets.all(14), children: [
          _banner(),
          for (final d in docs) _burbuja(d.data()),
          if (!widget.comoSoporte && !cerrado && docs.length <= 1) _sugerencias(),
        ]);
      },
    );
  }

  Widget _banner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline, color: AppColors.verde, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.comoSoporte
                  ? 'Estás atendiendo este ticket como agente de soporte. Tus respuestas llegan al usuario al instante.'
                  : 'Cuéntanos tu problema. Un agente de soporte te responderá en este chat.',
              style: const TextStyle(fontSize: 13, color: AppColors.gris, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _sugerencias() => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.bolt, size: 15, color: AppColors.verde),
            SizedBox(width: 4),
            Text('Respuestas sugeridas:', style: TextStyle(fontSize: 12, color: AppColors.gris, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _sugeridas)
              GestureDetector(
                onTap: () => _enviar(s.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.tarjeta, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.$1, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Icon(s.$2, size: 14, color: AppColors.verde),
                  ]),
                ),
              ),
          ]),
        ]),
      );

  Widget _entrada(bool cerrado) {
    if (cerrado) {
      return Container(
        padding: const EdgeInsets.all(14),
        color: AppColors.tarjeta,
        child: SafeArea(
          top: false,
          child: Row(children: [
            const Expanded(child: Text('Este ticket está cerrado.', style: TextStyle(color: AppColors.gris))),
            if (!widget.comoSoporte)
              TextButton(
                onPressed: () => setState(() => _ticketId = null),
                child: const Text('Abrir nuevo ticket'),
              ),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: AppColors.fondo,
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _texto,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje aquí…',
                filled: true,
                fillColor: AppColors.tarjeta,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _enviar,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(color: AppColors.verde, shape: BoxShape.circle),
              child: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send, color: Colors.black, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: AppColors.verde))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _ticketId == null ? const Stream.empty() : SoporteProvider.ticket(_ticketId!),
                builder: (context, snap) {
                  final t = snap.data?.data();
                  final cerrado = t?['estado'] == 'cerrado';
                  return Column(children: [
                    _cabecera(t),
                    _tarjetaTicket(t),
                    const SizedBox(height: 10),
                    Expanded(child: _lista(t)),
                    _entrada(cerrado),
                  ]);
                },
              ),
      ),
    );
  }
}