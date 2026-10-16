import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/descarga.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/club_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/instalar_app.dart';
import '../app_shell.dart';

/// Perfil, ajustes y accesos de gestión.
class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final t = Theme.of(context).textTheme;
    final push = context.read<PushService>();

    return Scaffold(
      appBar: const TabAppBar(title: 'Más'),
      body: PageBody(
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              leading: Avatar(user.iniciales, size: 48),
              title: Text(user.nombreVisible, style: t.titleMedium),
              subtitle: Text('${user.role.label} · ${user.email}'),
            ),
          ),
          if (user.role.isDireccion) ...[
            const SectionHeader('Gestión del club'),
            const CardList(children: [
              _Enlace(Icons.insights, 'Cuadro de mandos e informes', '/informes'),
              _Enlace(Icons.school_outlined, 'Alumnas y códigos', '/alumnas'),
              _Enlace(Icons.family_restroom_outlined, 'Familias y cuentas', '/familias'),
              _Enlace(Icons.groups_outlined, 'Grupos, horarios y cuotas',
                  '/grupos'),
              _Enlace(Icons.badge_outlined, 'Equipo y cuentas', '/equipo'),
              _Enlace(Icons.fact_check_outlined, 'Asistencia por grupo',
                  '/asistencia'),
              _Enlace(Icons.account_balance_outlined, 'Datos bancarios',
                  '/datos-bancarios'),
            ]),
          ],
          const SectionHeader('Mi cuenta'),
          CardList(children: [
            if (user.role.isFamilia)
              ListTile(
                leading: const Icon(Icons.link, color: AppColors.navy),
                title: const Text('Vincular otra alumna'),
                subtitle: const Text('Con el código que te dio el club'),
                onTap: () => _vincular(context),
              ),
            if (push.disponible)
              ListTile(
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.navy,
                ),
                title: const Text('Activar avisos en este dispositivo'),
                subtitle: const Text(
                  'En iPhone, primero añade la app a la pantalla de inicio.',
                ),
                onTap: () async {
                  final ok = await push.activar(user.uid);
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      ok
                          ? 'Avisos activados.'
                          : 'El navegador no ha permitido los avisos.',
                      isError: !ok,
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.navy),
              title: const Text('Cambiar contraseña'),
              onTap: () => _cambiarPassword(context),
            ),
            ListTile(
              leading: const Icon(Icons.install_mobile, color: AppColors.navy),
              title: const Text('Instalar en el móvil'),
              subtitle: const Text('Cómo tener la app como un icono más'),
              onTap: () => mostrarInstalarApp(context),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.navy),
              title: const Text('Política de privacidad'),
              onTap: () => context.push('/privacidad'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.navy),
              title: const Text('Condiciones de uso'),
              onTap: () => context.push('/terminos'),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined, color: AppColors.navy),
              title: const Text('Descargar mis datos'),
              subtitle: const Text('Una copia de tu información en un archivo'),
              onTap: () => _descargarDatos(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: AppColors.danger),
              title: const Text('Eliminar mi cuenta',
                  style: TextStyle(color: AppColors.danger)),
              subtitle: const Text('Borra tu acceso y tus datos personales'),
              onTap: () => _eliminarCuenta(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                await push.desregistrar();
                if (context.mounted) {
                  await context.read<SessionController>().signOut();
                }
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: ClubLogo(height: 64)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tus datos están protegidos: cada perfil sólo accede a lo que le '
            'corresponde.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _vincular(BuildContext context) async {
    final session = context.read<SessionController>();
    final codigo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular otra alumna'),
        content: TextField(
          controller: codigo,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código del club'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final nombre = await session.vincular(codigo.text);
      if (context.mounted) {
        showAppSnackBar(context, '$nombre ya está vinculada a tu cuenta.');
      }
    } on RegistroException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  Future<void> _descargarDatos(BuildContext context) async {
    final session = context.read<SessionController>();
    try {
      final json = await session.exportarMisDatos();
      descargarTexto('mis-datos-spado-rackets.json', json,
          tipo: 'application/json');
      if (context.mounted) {
        showAppSnackBar(context, 'Archivo descargado.');
      }
    } on RegistroException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudieron preparar tus datos.',
            isError: true);
      }
    }
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    final session = context.read<SessionController>();
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borran tu acceso, tus justificantes y tus mensajes '
              'privados, y dejas de estar vinculada a tus hijas. El club '
              'conserva, sin tu nombre, la asistencia y las cuotas que debe '
              'guardar por contabilidad. No se puede deshacer.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Escribe tu contraseña para confirmar',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || password.text.isEmpty) return;
    try {
      await session.eliminarMiCuenta(password.text);
    } on RegistroException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  Future<void> _cambiarPassword(BuildContext context) async {
    final session = context.read<SessionController>();
    final actual = TextEditingController();
    final nueva = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: actual,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: nueva,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña nueva',
                helperText: 'Mínimo 8 caracteres',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (nueva.text.length < 8) {
      if (context.mounted) {
        showAppSnackBar(context, 'La nueva contraseña es demasiado corta.',
            isError: true);
      }
      return;
    }
    try {
      await session.cambiarPassword(actual: actual.text, nueva: nueva.text);
      if (context.mounted) showAppSnackBar(context, 'Contraseña cambiada.');
    } on RegistroException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }
}

class _Enlace extends StatelessWidget {
  const _Enlace(this.icon, this.titulo, this.ruta);
  final IconData icon;
  final String titulo;
  final String ruta;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.navy),
        title: Text(titulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(ruta),
      );
}
