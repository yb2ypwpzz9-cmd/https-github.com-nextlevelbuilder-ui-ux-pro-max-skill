import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Botones para llamar o escribir por WhatsApp a un teléfono de contacto.
class BotonesContacto extends StatelessWidget {
  const BotonesContacto(this.telefono, {super.key});

  final String telefono;

  String get _digitos => telefono.replaceAll(RegExp(r'[^0-9]'), '');

  /// Los números dominicanos de 10 cifras (809, 829, 849) llevan el prefijo 1.
  String get _internacional =>
      _digitos.length == 10 ? '1$_digitos' : _digitos;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Llamar a $telefono',
          icon: const Icon(Icons.phone_outlined, color: AppColors.navy),
          onPressed: () => launchUrl(Uri(scheme: 'tel', path: telefono)),
        ),
        IconButton(
          tooltip: 'WhatsApp',
          icon: const Icon(Icons.chat_outlined, color: AppColors.success),
          onPressed: () => launchUrl(
            Uri.parse('https://wa.me/$_internacional'),
            webOnlyWindowName: '_blank',
          ),
        ),
      ],
    );
  }
}
