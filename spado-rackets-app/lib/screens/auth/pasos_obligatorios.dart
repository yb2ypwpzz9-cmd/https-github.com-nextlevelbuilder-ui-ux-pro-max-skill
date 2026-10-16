import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/textos_legales.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Primer acceso con la contraseña provisional que entregó Dirección: nadie
/// más que la propia persona debe conocer la definitiva.
class CambiarPasswordObligatorioScreen extends StatefulWidget {
  const CambiarPasswordObligatorioScreen({super.key});

  @override
  State<CambiarPasswordObligatorioScreen> createState() =>
      _CambiarPasswordObligatorioScreenState();
}

class _CambiarPasswordObligatorioScreenState
    extends State<CambiarPasswordObligatorioScreen> {
  final _form = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final session = context.read<SessionController>();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await session.cambiarPasswordObligatorio(
        actual: _actual.text,
        nueva: _nueva.text,
      );
    } on RegistroException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cambiar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      subtitulo: 'Tu contraseña provisional solo sirve para este primer acceso.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Crea tu contraseña',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _actual,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Contraseña provisional'),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Escribe la contraseña provisional' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nueva,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña nueva',
                helperText: 'Mínimo 8 caracteres',
              ),
              validator: (v) {
                if ((v ?? '').length < 8) return 'Mínimo 8 caracteres';
                if (v == _actual.text) return 'Tiene que ser distinta';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              InlineNotice(
                message: _error!,
                icon: Icons.error_outline,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Guardar y entrar'),
            ),
            TextButton(
              onPressed: () => context.read<SessionController>().signOut(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Información al personal sobre lo que se registra al fichar. Hay que
/// leerla y aceptarla una vez (y de nuevo si cambia el texto).
class AvisoUbicacionScreen extends StatefulWidget {
  const AvisoUbicacionScreen({super.key});

  @override
  State<AvisoUbicacionScreen> createState() => _AvisoUbicacionScreenState();
}

class _AvisoUbicacionScreenState extends State<AvisoUbicacionScreen> {
  bool _guardando = false;

  Future<void> _aceptar() async {
    final session = context.read<SessionController>();
    setState(() => _guardando = true);
    try {
      await session.aceptarAvisoUbicacion();
    } catch (_) {
      if (mounted) {
        setState(() => _guardando = false);
        showAppSnackBar(context, 'No se pudo guardar. Inténtalo de nuevo.',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthFrame(
      subtitulo: 'Léelo antes de empezar a usar el fichaje.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TextosLegales.avisoStaffTitulo, style: t.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final (titulo, texto) in TextosLegales.avisoStaff) ...[
            Text(titulo, style: t.titleSmall),
            const SizedBox(height: 2),
            Text(texto, style: t.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: _guardando ? null : _aceptar,
            child: Text(_guardando ? 'Guardando…' : 'He leído el aviso'),
          ),
          TextButton(
            onPressed: () => context.read<SessionController>().signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
