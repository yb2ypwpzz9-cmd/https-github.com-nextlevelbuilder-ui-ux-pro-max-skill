import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/alumna.dart';
import '../theme/app_theme.dart';
import 'common.dart';

const _enlaceApp = 'https://spado-rackets.netlify.app';

/// Mensaje para invitar a una familia a entrar en la app.
String textoInvitacion(Alumna alumna, String codigo) {
  final correo = alumna.emailFamilia;
  return 'Hola, te damos acceso a la app de Spado Rackets, donde verás el '
      'horario de ${alumna.nombreCorto}, los avisos del club y las cuotas.\n\n'
      '1. Entra en $_enlaceApp\n'
      '2. Pulsa "Crear cuenta" y regístrate con '
      '${correo == null ? 'tu correo' : 'este mismo correo ($correo)'} y '
      'este código: $codigo\n'
      '3. Elige tu propia contraseña y confirma tu correo.\n\n'
      'Para tenerla como una app: en iPhone, abre el enlace en Safari → '
      'Compartir → "Añadir a pantalla de inicio". En Android, Chrome → menú ⋮ '
      '→ "Instalar aplicación".';
}

/// Hoja para mandar la invitación por WhatsApp o correo, o copiarla. No envía
/// nada por su cuenta: abre WhatsApp o el correo con el mensaje ya escrito.
void mostrarInvitacion(BuildContext context, Alumna alumna, String codigo) {
  final mensaje = textoInvitacion(alumna, codigo);
  final telefono = alumna.contactoTelefono;
  final correo = alumna.emailFamilia;

  String internacional(String t) {
    final d = t.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length == 10 ? '1$d' : d;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invitar a la familia de ${alumna.nombreCorto}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(mensaje,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://wa.me/${telefono == null ? '' : internacional(telefono)}'
                    '?text=${Uri.encodeComponent(mensaje)}'),
                webOnlyWindowName: '_blank',
              ),
              icon: const Icon(Icons.chat_outlined),
              label: Text(telefono == null
                  ? 'WhatsApp (elegir contacto)'
                  : 'WhatsApp a $telefono'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => launchUrl(Uri.parse(
                  'mailto:${correo ?? ''}'
                  '?subject=${Uri.encodeComponent('Acceso a la app de Spado Rackets')}'
                  '&body=${Uri.encodeComponent(mensaje)}')),
              icon: const Icon(Icons.mail_outline),
              label: Text(correo == null ? 'Correo' : 'Correo a $correo'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: mensaje));
                if (sheet.mounted) {
                  Navigator.of(sheet).pop();
                  showAppSnackBar(context, 'Mensaje copiado.');
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar el mensaje'),
            ),
          ],
        ),
      ),
    ),
  );
}
