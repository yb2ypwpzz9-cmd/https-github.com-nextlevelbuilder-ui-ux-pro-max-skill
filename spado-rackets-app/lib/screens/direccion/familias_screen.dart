import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/app_user.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Dirección: cuentas de las familias. Ver, editar el contacto, restablecer
/// la contraseña o eliminar la cuenta.
class FamiliasScreen extends StatelessWidget {
  const FamiliasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Familias y cuentas')),
      body: StreamView<List<AppUser>>(
        stream: repo.watchFamilias(),
        builder: (context, familias) => StreamView<List<Alumna>>(
          stream: repo.watchTodasLasAlumnas(),
          builder: (context, alumnas) {
            List<Alumna> hijas(AppUser f) =>
                alumnas.where((a) => a.familiaUid == f.uid).toList();
            return PageBody(
              children: [
                BotonExcel(
                  onPressed: () => descargarExcel('familias', {
                    'Familias': [
                      ['Nombre', 'Email', 'Teléfono', 'Alumnado'],
                      for (final f in familias)
                        [
                          f.nombreVisible,
                          f.email,
                          f.phone,
                          hijas(f).map((a) => a.nombre).join(', '),
                        ],
                    ],
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (familias.isEmpty)
                  const EmptyState(
                    compacto: true,
                    icon: Icons.family_restroom_outlined,
                    title: 'Todavía no se ha registrado ninguna familia',
                    message: 'Aparecerán aquí cuando usen el código de su '
                        'hijo o hija para crear la cuenta.',
                  )
                else
                  CardList(
                    children: [
                      for (final f in familias)
                        ListTile(
                          leading: Avatar(f.iniciales),
                          title: Text(f.nombreVisible),
                          subtitle: Text([
                            f.email,
                            if (hijas(f).isNotEmpty)
                              hijas(f).map((a) => a.nombreCorto).join(', '),
                          ].join(' · ')),
                          trailing: const Icon(Icons.edit_outlined, size: 20),
                          onTap: () => _editar(context, f, hijas(f)),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editar(
    BuildContext context,
    AppUser familia,
    List<Alumna> hijas,
  ) async {
    final repo = context.read<ClubRepository>();
    final raiz = context;
    final nombre = TextEditingController(text: familia.nombreVisible);
    final telefono = TextEditingController(text: familia.phone ?? '');

    final guardar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          pieHoja(context),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cuenta de familia',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${familia.email}${hijas.isEmpty ? '' : ' · ${hijas.map((a) => a.nombre).join(', ')}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Restablecer contraseña'),
                onPressed: () async {
                  final ok = await confirmar(
                    context,
                    titulo: 'Restablecer contraseña',
                    mensaje: 'Se crea una contraseña provisional para '
                        '${familia.nombreVisible}; tendrá que cambiarla al '
                        'entrar. La anterior deja de valer.',
                    accion: 'Restablecer',
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    final pass =
                        await repo.restablecerPasswordCuentaClub(familia.uid);
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Contraseña nueva'),
                        content: SelectableText(
                          'Email: ${familia.email}\nContraseña: $pass\n\n'
                          'No se vuelve a mostrar.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: pass)),
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
                          context, '$e'.replaceFirst('Exception: ', ''),
                          isError: true);
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
                    titulo: 'Eliminar la cuenta de ${familia.nombreVisible}',
                    mensaje: 'Pierde el acceso y se borran sus justificantes y '
                        'mensajes privados. Sus hijos e hijas siguen en el club, sin '
                        'cuenta vinculada, y se pueden vincular de nuevo con '
                        'su código.',
                    accion: 'Eliminar',
                    peligrosa: true,
                  );
                  if (!ok) return;
                  try {
                    await repo.eliminarCuentaClub(familia.uid);
                    if (context.mounted) Navigator.pop(context, false);
                    if (raiz.mounted) {
                      showAppSnackBar(raiz, 'Cuenta eliminada.');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showAppSnackBar(
                          context, '$e'.replaceFirst('Exception: ', ''),
                          isError: true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (guardar != true) return;
    try {
      await repo.actualizarContactoFamilia(
        familia.uid,
        nombre: nombre.text,
        telefono: telefono.text,
      );
      if (raiz.mounted) showAppSnackBar(raiz, 'Guardado.');
    } catch (_) {
      if (raiz.mounted) {
        showAppSnackBar(raiz, 'No se pudo guardar.', isError: true);
      }
    }
  }
}
