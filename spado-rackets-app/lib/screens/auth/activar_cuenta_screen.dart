import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Primer acceso del equipo (entrenadores y Dirección): el correo que dio de
/// alta el club, el código que se le entregó y la contraseña que quiera.
class ActivarCuentaScreen extends StatefulWidget {
  const ActivarCuentaScreen({super.key});

  @override
  State<ActivarCuentaScreen> createState() => _ActivarCuentaScreenState();
}

class _ActivarCuentaScreenState extends State<ActivarCuentaScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  bool _ver = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _activar() async {
    if (!_form.currentState!.validate()) return;
    final session = context.read<SessionController>();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await session.activarCuenta(
        email: _email.text,
        codigo: _codigo.text,
        password: _password.text,
      );
      // El router lleva solo a la app al detectar la sesión.
    } on RegistroException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo activar. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthFrame(
      volverA: '/login',
      subtitulo: 'Primer acceso del equipo del club.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Activa tu cuenta', style: t.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Usa el correo que diste a Dirección y el código que te '
              'entregaron. Después elige tu contraseña.',
              style: t.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Escribe tu email',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de activación',
                hintText: 'Ej. K7M2QX4P',
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 4 ? 'Escribe el código' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: !_ver,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Tu contraseña',
                helperText: 'Mínimo 8 caracteres',
                suffixIcon: IconButton(
                  tooltip: _ver ? 'Ocultar' : 'Mostrar',
                  icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _ver = !_ver),
                ),
              ),
              validator: (v) => (v ?? '').length < 8
                  ? 'La contraseña debe tener al menos 8 caracteres'
                  : null,
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
              onPressed: _cargando ? null : _activar,
              child: Text(_cargando ? 'Activando…' : 'Activar y entrar'),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Ya tengo contraseña: iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
