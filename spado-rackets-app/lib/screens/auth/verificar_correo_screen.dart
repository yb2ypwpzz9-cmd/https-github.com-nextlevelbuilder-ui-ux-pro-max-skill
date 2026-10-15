import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Paso obligatorio tras registrarse: el enlace que llega por correo confirma
/// que la cuenta es de quien dice. Hasta entonces no se vincula a la alumna.
class VerificarCorreoScreen extends StatefulWidget {
  const VerificarCorreoScreen({super.key});

  @override
  State<VerificarCorreoScreen> createState() => _VerificarCorreoScreenState();
}

class _VerificarCorreoScreenState extends State<VerificarCorreoScreen> {
  bool _comprobando = false;
  String? _error;

  Future<void> _comprobar() async {
    final session = context.read<SessionController>();
    setState(() {
      _comprobando = true;
      _error = null;
    });
    try {
      final ok = await session.comprobarVerificacion();
      if (!ok && mounted) {
        setState(() => _error =
            'Todavía no está verificado. Abre el enlace del correo y vuelve '
            'a pulsar el botón.');
      }
    } on RegistroException catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.message, isError: true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo comprobar. Reintenta.');
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

  Future<void> _reenviar() async {
    final session = context.read<SessionController>();
    try {
      await session.reenviarVerificacion();
      if (mounted) showAppSnackBar(context, 'Correo reenviado.');
    } on RegistroException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final email = session.firebaseUser?.email ?? '';
    return AuthFrame(
      subtitulo: 'Un último paso para proteger los datos de tu hija.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Verifica tu correo',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Te hemos enviado un enlace a $email. Ábrelo (mira también en '
            'spam) y vuelve aquí.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (_error != null) ...[
            InlineNotice(
              message: _error!,
              icon: Icons.info_outline,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: _comprobando ? null : _comprobar,
            child: Text(_comprobando ? 'Comprobando…' : 'Ya lo he verificado'),
          ),
          TextButton(onPressed: _reenviar, child: const Text('Reenviar correo')),
          TextButton(
            onPressed: () => context.read<SessionController>().signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
