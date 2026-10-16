import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Alta de familias. Staff y Dirección no se registran: les crea la cuenta
/// Dirección desde la app.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _codigo = TextEditingController();
  bool _cargando = false;
  bool _acepta = false;
  bool _tutor = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _email, _password, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    if (!_tutor) {
      setState(() => _error = 'Para crear la cuenta tienes que confirmar que '
          'eres madre, padre o tutor legal de la alumna.');
      return;
    }
    if (!_acepta) {
      setState(() => _error =
          'Para crear la cuenta tienes que aceptar la política de privacidad.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().registrarFamilia(
            email: _email.text,
            password: _password.text,
            codigo: _codigo.text,
            nombre: _nombre.text,
            telefono: _telefono.text,
          );
      // El router redirige solo al detectar la sesión.
    } on RegistroException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthFrame(
      volverA: '/login',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Crear cuenta de familia', style: t.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Necesitas el código que te entregó el club (uno por hija). '
              'Si tienes dos hijas en la escuela, usa uno ahora y añade el otro '
              'después desde "Más".',
              style: t.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código del club',
                hintText: 'Ej. K7M2QX4P',
              ),
              validator: (v) => (v ?? '').trim().length < 4
                  ? 'Escribe el código que te dio el club'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre y apellidos del padre, madre o tutor',
                hintText: 'Así te verá el club en los mensajes',
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Escribe tu nombre' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                hintText: '809 000 0000',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Escribe un email válido',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Mínimo 8 caracteres',
              ),
              validator: (v) => (v ?? '').length < 8
                  ? 'La contraseña debe tener al menos 8 caracteres'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _tutor,
              onChanged: (v) => setState(() => _tutor = v ?? false),
              title: Text(
                'Soy la madre, el padre o el tutor legal de la alumna y '
                'autorizo que el club trate sus datos para gestionar su '
                'actividad.',
                style: t.bodySmall,
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acepta,
              onChanged: (v) => setState(() => _acepta = v ?? false),
              title: Text.rich(
                TextSpan(
                  style: t.bodySmall,
                  children: [
                    const TextSpan(text: 'He leído y acepto la '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: InkWell(
                        onTap: () => context.push('/privacidad'),
                        child: Text(
                          'política de privacidad',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' y las '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: InkWell(
                        onTap: () => context.push('/terminos'),
                        child: Text(
                          'condiciones de uso',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null) ...[
              InlineNotice(
                message: _error!,
                icon: Icons.error_outline,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton(
              onPressed: _cargando ? null : _registrar,
              child: _cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Ya tengo cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
