import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';

import '../models/alumna.dart';
import '../services/club_repository.dart';
import '../services/firestore_refs.dart';
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
void mostrarInvitacion(
  BuildContext context,
  Alumna alumna,
  String codigo, {
  String? usadoPor,
}) {
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
            const SizedBox(height: AppSpacing.sm),
            InlineNotice(
              icon: Icons.mark_email_read_outlined,
              message: correo == null
                  ? 'La ficha no tiene correo reservado: cualquier correo puede '
                      'usar este código.'
                  : 'Código reservado para $correo. Si ese correo está mal, '
                      'corrígelo en la ficha (toca a la persona en la lista): '
                      'el código sigue valiendo.',
            ),
            if (usadoPor != null) _CuentaQueLoUso(uid: usadoPor),
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
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size(0, 44)),
              onPressed: () async {
                final repo = context.read<ClubRepository>();
                final ok = await confirmar(
                  context,
                  titulo: 'Código nuevo para ${alumna.nombreCorto}',
                  mensaje: 'El código actual dejará de valer y se crea otro. '
                      'Úsalo si la familia se equivocó al registrarse o si el '
                      'código ya no le funciona. Luego envíale la invitación '
                      'otra vez.',
                  accion: 'Generar código nuevo',
                  peligrosa: true,
                );
                if (!ok) return;
                try {
                  final nuevo = await repo.regenerarCodigo(alumna.id);
                  if (sheet.mounted) Navigator.of(sheet).pop();
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      'Código nuevo: $nuevo. Pulsa el icono de enviar para '
                      'mandárselo.',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    showAppSnackBar(context, 'No se pudo generar el código.',
                        isError: true);
                  }
                }
              },
              icon: const Icon(Icons.autorenew, size: 18),
              label: const Text('Generar código nuevo'),
            ),
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


/// Si el código ya lo usó una cuenta, quién es: así se ve si fue con el correo
/// equivocado.
class _CuentaQueLoUso extends StatelessWidget {
  const _CuentaQueLoUso({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Refs.users.doc(uid).get(),
      builder: (context, snap) {
        final correo = snap.data?.data()?['email'] as String?;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InlineNotice(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            message: snap.connectionState != ConnectionState.done
                ? 'Este código ya se ha usado…'
                : 'Este código ya lo usó una cuenta${correo == null ? ' (ya no existe)' : ' ($correo)'}. '
                    'Si no es la familia correcta, genera un código nuevo.',
          ),
        );
      },
    );
  }
}
