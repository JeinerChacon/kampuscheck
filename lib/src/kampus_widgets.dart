import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Pastilla superior: "CONTROL DE ASISTENCIA DIGITAL"
class PillLabel extends StatelessWidget {
  final String texto;
  final bool conPunto;
  const PillLabel(this.texto, {super.key, this.conPunto = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conPunto)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                  color: AppColors.verde, shape: BoxShape.circle),
            ),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: AppColors.gris,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo "KampusCheck"
class KampusLogo extends StatelessWidget {
  final String subtitulo;
  final double tamano;
  const KampusLogo(
      {super.key, this.subtitulo = 'ASISTENCIA DIGITAL', this.tamano = 30});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.tarjeta,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borde),
              ),
              child: Icon(Icons.school, color: AppColors.verde, size: tamano),
            ),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: tamano, fontWeight: FontWeight.bold),
                children: const [
                  TextSpan(
                      text: 'Kampus',
                      style: TextStyle(color: AppColors.texto)),
                  TextSpan(
                      text: 'Check',
                      style: TextStyle(color: AppColors.verde)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: const TextStyle(
              fontSize: 10, letterSpacing: 2, color: AppColors.gris),
        ),
      ],
    );
  }
}

/// Tarjeta contenedora
class KampusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  const KampusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.tarjeta,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AppColors.borde),
      ),
      // Material transparente: los ListTile / ExpansionTile dentro de la tarjeta
      // pueden pintar su ripple (evita el aviso "ListTile background color...").
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Tabs Estudiante / Docente
class RoleTabs extends StatelessWidget {
  final bool esEstudiante;
  final ValueChanged<bool> onChanged;
  final bool esSoporte; // acceso de soporte (menú de tres puntos)
  final VoidCallback? onSoporte;
  const RoleTabs(
      {super.key,
      required this.esEstudiante,
      required this.onChanged,
      this.esSoporte = false,
      this.onSoporte});

  Widget _tab(String texto, IconData icono, bool activo, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: activo ? AppColors.verdeOscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono,
                  size: 18, color: activo ? Colors.black : AppColors.gris),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  color: activo ? Colors.black : AppColors.gris,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tab('Estudiante', Icons.school_outlined, esEstudiante && !esSoporte,
              () => onChanged(true)),
          _tab('Docente', Icons.badge_outlined, !esEstudiante && !esSoporte,
              () => onChanged(false)),
          if (onSoporte != null)
            PopupMenuButton<String>(
              tooltip: 'Más roles',
              color: AppColors.tarjeta,
              onSelected: (_) => onSoporte!(),
              icon: Icon(Icons.more_vert,
                  size: 20, color: esSoporte ? AppColors.verde : AppColors.gris),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'soporte',
                  child: Row(children: [
                    Icon(Icons.support_agent,
                        size: 18, color: esSoporte ? AppColors.verde : AppColors.gris),
                    const SizedBox(width: 8),
                    Text(esSoporte ? 'Soporte (activo)' : 'Entrar como Soporte'),
                  ]),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Campo de texto con etiqueta, icono y estado de error
class KampusField extends StatelessWidget {
  final String etiqueta;
  final String hint;
  final IconData icono;
  final TextEditingController? controller;
  final bool esPassword;
  final bool oculto;
  final VoidCallback? onToggleOculto;
  final String? etiquetaDerecha;
  final Widget? widgetDerecha;
  final String? error;
  final TextInputType? teclado;
  final ValueChanged<String>? onChanged;

  const KampusField({
    super.key,
    required this.etiqueta,
    required this.hint,
    required this.icono,
    this.controller,
    this.esPassword = false,
    this.oculto = false,
    this.onToggleOculto,
    this.etiquetaDerecha,
    this.widgetDerecha,
    this.error,
    this.teclado,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hayError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiqueta,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hayError ? AppColors.rojo : AppColors.texto)),
            ?widgetDerecha,
            if (etiquetaDerecha != null)
              Text(etiquetaDerecha!,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.verde)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: hayError ? AppColors.rojoFondo : AppColors.campo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: hayError ? AppColors.rojo : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(icono,
                  size: 20,
                  color: hayError ? AppColors.rojo : AppColors.gris),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: esPassword && oculto,
                  keyboardType: teclado,
                  onChanged: onChanged,
                  style: const TextStyle(color: AppColors.texto),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.gris),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              if (esPassword)
                GestureDetector(
                  onTap: onToggleOculto,
                  child: Icon(
                    oculto ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: AppColors.gris,
                  ),
                ),
            ],
          ),
        ),
        if (hayError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('▸ $error',
                style: const TextStyle(fontSize: 12, color: AppColors.rojo)),
          ),
      ],
    );
  }
}

/// Selector tipo dropdown
class KampusDropdown extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final String valor;
  final List<String> opciones;
  final ValueChanged<String> onChanged;
  const KampusDropdown({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.campo,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icono, size: 20, color: AppColors.gris),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: valor,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.tarjeta,
                  items: opciones
                      .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => onChanged(v!),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón principal verde
class PrimaryButton extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool cargando;
  const PrimaryButton({
    super.key,
    required this.texto,
    this.icono = Icons.arrow_forward,
    this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return GestureDetector(
      onTap: activo ? onPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: activo ? AppColors.verde : AppColors.borde,
          borderRadius: BorderRadius.circular(30),
        ),
        child: cargando
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(texto,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: activo ? Colors.black : AppColors.gris)),
                  if (icono != null) ...[
                    const SizedBox(width: 8),
                    Icon(icono,
                        size: 18,
                        color: activo ? Colors.black : AppColors.gris),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Caja informativa (icono + texto)
class InfoBox extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const InfoBox({
    super.key,
    required this.icono,
    required this.texto,
    this.color = AppColors.verde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.gris, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Barra "¿Problemas? Contactar Mesa de Ayuda"
class HelpDeskBar extends StatelessWidget {
  final String pregunta;
  const HelpDeskBar({super.key, this.pregunta = '¿Problemas para ingresar?'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.support_agent, size: 16, color: AppColors.verde),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '$pregunta ',
                style: const TextStyle(fontSize: 12, color: AppColors.gris),
                children: const [
                  TextSpan(
                    text: 'Contactar Mesa de Ayuda',
                    style: TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie "KampusCheck Secure Terminal • v2.6.4"
class SecureFooter extends StatelessWidget {
  const SecureFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text('KampusCheck Secure Terminal • v2.6.4',
          style: TextStyle(fontSize: 11, color: AppColors.gris)),
    );
  }
}