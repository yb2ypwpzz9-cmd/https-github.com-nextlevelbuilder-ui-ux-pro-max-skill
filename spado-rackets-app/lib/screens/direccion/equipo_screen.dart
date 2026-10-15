import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/grupo.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Cuentas del club (staff y Dirección) y sus grupos.
class EquipoScreen extends StatelessWidget {
  const EquipoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubRepository>();
    return StreamView<List<Grupo>>(
      stream: repo.watchGrupos(),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, grupos) => Scaffold(
        appBar: AppBar(title: const Text('Equipo')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          onPressed: () => _crear(context, grupos),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Nueva cuenta'),
        ),
        body: StreamView<List<AppUser>>(
          stream: repo.watchCuentasDelClub(),
          builder: (context, cuentas) => PageBody(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const InlineNotice(
                message: 'El staff sólo ve las alumnas, listas y chats de los '
                    'grupos que tenga asignados. Dirección lo ve todo.',
              ),
              const SizedBox(height: AppSpacing.md),
              CardList(
                children: [
                  for (final c in cuentas)
                    ListTile(
                      leading: Avatar(c.iniciales),
                      title: Text(c.nombreVisible),
                      subtitle: Text(
                        c.role.isDireccion
                            ? 'Dirección · acceso completo'
                            : c.grupos.isEmpty
                                ? 'Staff · sin grupos'
                                : 'Staff · ${grupos.where((g) => c.grupos.contains(g.id)).map((g) => g.nombre).join(', ')}',
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editar(context, c, grupos),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editar(
    BuildContext context,
    AppUser cuenta,
    List<Grupo> grupos,
  ) async {
    final repo = context.read<ClubRepository>();
    final yo = context.read<SessionController>().appUser!;
    final esYo = cuenta.uid == yo.uid;
    final nombre = TextEditingController(text: cuenta.nombreVisible);
    var rol = cuenta.role;
    final elegidos = {...cuenta.grupos};
    final raiz = context;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Editar cuenta',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(cuenta.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nombre,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Nombre y apellido'),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(value: UserRole.staff, label: Text('Staff')),
                    ButtonSegment(
                        value: UserRole.direccion, label: Text('Dirección')),
                  ],
                  selected: {rol},
                  showSelectedIcon: false,
                  // Cambiarte el rol a ti mismo te dejaría sin acceso.
                  onSelectionChanged:
                      esYo ? null : (s) => setSheet(() => rol = s.first),
                ),
                if (rol.isStaff) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Grupos', style: Theme.of(context).textTheme.labelLarge),
                  for (final g in grupos)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.nombre),
                      subtitle: Text(g.horarioTexto),
                      value: elegidos.contains(g.id),
                      onChanged: (v) => setSheet(
                        () => v == true
                            ? elegidos.add(g.id)
                            : elegidos.remove(g.id),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
                if (!esYo) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Restablecer contraseña'),
                    onPressed: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Restablecer contraseña',
                        mensaje: 'Se crea una contraseña provisional nueva '
                            'para ${cuenta.nombreVisible}. La anterior deja '
                            'de valer.',
                        accion: 'Restablecer',
                      );
                      if (!ok || !context.mounted) return;
                      try {
                        final pass =
                            await repo.restablecerPasswordCuentaClub(cuenta.uid);
                        if (!context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Contraseña nueva'),
                            content: SelectableText(
                              'Email: ${cuenta.email}\nContraseña: $pass\n\n'
                              'No se vuelve a mostrar.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Clipboard.setData(
                                    ClipboardData(text: pass)),
                                child: const Text('Copiar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Hecho'),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          showAppSnackBar(
                            context,
                            '$e'.replaceFirst('Exception: ', ''),
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar cuenta'),
                    onPressed: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Eliminar a ${cuenta.nombreVisible}',
                        mensaje: 'Pierde el acceso a la app de inmediato. Sus '
                            'fichajes y mensajes anteriores se conservan.',
                        accion: 'Eliminar',
                        peligrosa: true,
                      );
                      if (!ok) return;
                      try {
                        await repo.eliminarCuentaClub(cuenta.uid);
                        if (context.mounted) Navigator.pop(context, false);
                        if (raiz.mounted) {
                          showAppSnackBar(raiz, 'Cuenta eliminada.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showAppSnackBar(
                            context,
                            '$e'.replaceFirst('Exception: ', ''),
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (nombre.text.trim().length < 2) {
      if (raiz.mounted) {
        showAppSnackBar(raiz, 'Pon un nombre.', isError: true);
      }
      return;
    }
    try {
      await repo.actualizarCuentaClub(
        cuenta.uid,
        nombre: nombre.text,
        rol: rol,
        grupos: elegidos.toList(),
      );
      if (raiz.mounted) showAppSnackBar(raiz, 'Cuenta actualizada.');
    } catch (_) {
      if (raiz.mounted) {
        showAppSnackBar(raiz, 'No se pudo guardar.', isError: true);
      }
    }
  }

  Future<void> _crear(BuildContext context, List<Grupo> grupos) async {
    final repo = context.read<ClubRepository>();
    final nombre = TextEditingController();
    final email = TextEditingController();
    var rol = UserRole.staff;
    final elegidos = <String>{};

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva cuenta del club',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nombre,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Nombre y apellido'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.staff,
                      label: Text('Staff'),
                    ),
                    ButtonSegment(
                      value: UserRole.direccion,
                      label: Text('Dirección'),
                    ),
                  ],
                  selected: {rol},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setSheet(() => rol = s.first),
                ),
                if (rol.isStaff) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Grupos', style: Theme.of(context).textTheme.labelLarge),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final g in grupos)
                        FilterChip(
                          label: Text(g.nombre),
                          selected: elegidos.contains(g.id),
                          onSelected: (v) => setSheet(
                            () => v ? elegidos.add(g.id) : elegidos.remove(g.id),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (!email.text.contains('@') || nombre.text.trim().length < 2) {
      if (context.mounted) {
        showAppSnackBar(context, 'Revisa el nombre y el email.', isError: true);
      }
      return;
    }

    try {
      final password = await repo.crearCuentaClub(
        email: email.text,
        nombre: nombre.text,
        rol: rol,
        grupos: rol.isStaff ? elegidos.toList() : const [],
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cuenta creada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entrega estos datos a ${nombre.text.trim()}. La '
                  'contraseña no se vuelve a mostrar; podrá cambiarla desde '
                  '"Más".'),
              const SizedBox(height: AppSpacing.md),
              SelectableText('Email: ${email.text.trim()}'),
              SelectableText(
                'Contraseña: $password',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(
                text: 'Spado Rackets\nEmail: ${email.text.trim()}\n'
                    'Contraseña: $password',
              )),
              child: const Text('Copiar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Hecho'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          '$e'.replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }
}
