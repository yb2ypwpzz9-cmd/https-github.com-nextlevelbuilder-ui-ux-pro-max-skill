import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'instalar_app.dart';

/// Tarjeta de las pantallas de inicio que invita a activar los avisos. Los
/// navegadores solo dejan pedir el permiso tras un toque, así que no puede
/// salir sola: sin esta tarjeta nadie se enteraba de que había que activarlo.
/// Desaparece cuando los avisos ya están activos.
///
/// Se coloca debajo del primer bloque de cada inicio, no arriba del todo: si
/// aparece tarde, no empuja hacia abajo botones que la persona ya va a pulsar.
class AvisoNotificaciones extends StatefulWidget {
  const AvisoNotificaciones({super.key});

  @override
  State<AvisoNotificaciones> createState() => _AvisoNotificacionesState();
}

class _AvisoNotificacionesState extends State<AvisoNotificaciones> {
  late final PushService _push = context.read<PushService>();
  bool _oculto = false;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    if (_push.estadoActual.value == null) _push.refrescarEstado();
  }

  Future<void> _activar() async {
    if (_ocupado) return;
    final uid = context.read<SessionController>().appUser!.uid;
    setState(() {
      _ocupado = true;
    });
    final ok = await _push.activar(uid);
    await _push.refrescarEstado();
    if (!mounted) return;
    setState(() {
      _ocupado = false;
    });
    showAppSnackBar(
      context,
      ok
          ? 'Avisos activados en este dispositivo.'
          : 'No se pudieron activar. Revisa el permiso de notificaciones '
              'del navegador.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_oculto) return const SizedBox.shrink();
    return ValueListenableBuilder<EstadoPush?>(
      valueListenable: _push.estadoActual,
      builder: (context, estado, _) {
        if (estado == null || estado == EstadoPush.activo) {
          return const SizedBox.shrink();
        }
        final (texto, accion, etiqueta) = switch (estado) {
          EstadoPush.pendiente => (
              'Activa los avisos para enterarte al momento de las clases, '
                  'las cuotas y los mensajes del club.',
              _activar,
              'Activar avisos',
            ),
          EstadoPush.bloqueado => (
              'Los avisos están bloqueados en este dispositivo. Se activan '
                  'desde los ajustes de notificaciones del navegador o de la '
                  'app.',
              null,
              '',
            ),
          _ => (
              'Para recibir avisos en el móvil, añade la app a la pantalla '
                  'de inicio y ábrela desde su icono.',
              () => mostrarInstalarApp(context),
              'Cómo instalarla',
            ),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: InlineNotice(
            icon: Icons.notifications_active_outlined,
            message: texto,
            action: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (accion != null)
                  FilledButton(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: _ocupado ? null : accion,
                    child: _ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(etiqueta),
                  ),
                TextButton(
                  onPressed: () => setState(() => _oculto = true),
                  child: const Text('Ahora no'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
