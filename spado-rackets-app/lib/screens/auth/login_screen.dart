import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/club_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/instalar_app.dart';

/// Marco de las pantallas de acceso: logo blanco sobre azul y formulario en
/// una tarjeta.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    this.subtitulo,
    this.volverA,
  });

  /// Si se indica, arriba aparece una flecha para volver a esa ruta. Con la
  /// app en la pantalla de inicio no hay botón "atrás" del navegador.
  final String? volverA;
  final Widget child;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        if (volverA != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => context.go(volverA!),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Volver'),
                            ),
                          )
                        else
                          const SizedBox(height: AppSpacing.md),
                        const ClubLogo(height: 88),
                        if (subtitulo != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            subtitulo!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: child,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => mostrarInstalarApp(context),
                              icon: const Icon(Icons.install_mobile, size: 18),
                              label: const Text('Instalar en el móvil'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/privacidad'),
                              child: const Text('Política de privacidad'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/terminos'),
                              child: const Text('Condiciones de uso'),
                            ),
                          ],
                        ),
                        // Margen inferior: el borde de abajo del móvil lo
                        // reserva el sistema para sus gestos y los botones
                        // pegados a él no responden bien.
                        const SizedBox(height: 56),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(height: 6, color: AppColors.navy),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await context
          .read<SessionController>()
          .signIn(email: _email.text, password: _password.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = SessionController.mensajeAuth(e));
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _recuperar() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error =
          'Escribe tu email arriba y vuelve a pulsar "¿Olvidaste tu contraseña?".');
      return;
    }
    try {
      await context.read<SessionController>().sendPasswordReset(email);
      if (mounted) {
        showAppSnackBar(
          context,
          'Te hemos enviado un correo para crear una contraseña nueva.',
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = SessionController.mensajeAuth(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthFrame(
      subtitulo: 'Asistencia, cuotas y mensajes del club en un solo sitio.',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Iniciar sesión', style: t.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : 'Escribe un email válido',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: !_verPassword,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _entrar(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    tooltip: _verPassword ? 'Ocultar' : 'Mostrar',
                    icon: Icon(
                      _verPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _verPassword = !_verPassword),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _recuperar,
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              if (_error != null) ...[
                InlineNotice(
                  message: _error!,
                  icon: Icons.error_outline,
                  color: AppColors.danger,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              FilledButton(
                onPressed: _cargando ? null : _entrar,
                child: _cargando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Entrar'),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.go('/registro'),
                child: const Text('Crear cuenta con mi código'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.go('/activar'),
                child: const Text('Soy del equipo: primer acceso'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
