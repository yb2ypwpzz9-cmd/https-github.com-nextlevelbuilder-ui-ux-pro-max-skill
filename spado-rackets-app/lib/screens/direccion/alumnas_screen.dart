import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/grupo.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Alumnas por grupo, con el código que se entrega a cada familia.
class AlumnasScreen extends StatelessWidget {
  const AlumnasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubRepository>();
    return StreamView<List<Grupo>>(
      stream: repo.watchGrupos(),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, grupos) => Scaffold(
        appBar: AppBar(title: const Text('Alumnas y códigos')),
        floatingActionButton: grupos.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                onPressed: () => _editar(context, grupos, null),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Nueva alumna'),
              ),
        body: grupos.isEmpty
            ? const EmptyState(
                icon: Icons.groups_outlined,
                title: 'Primero crea los grupos',
                message: 'Cada alumna pertenece a un grupo. Ve a Más → '
                    'Grupos, horarios y cuotas.',
              )
            : StreamView<List<Alumna>>(
                stream: repo.watchTodasLasAlumnas(),
                builder: (context, alumnas) =>
                    StreamView<List<CodigoVinculacion>>(
                  stream: repo.watchCodigos(),
                  builder: (context, codigos) {
                    final codigoDe = {for (final c in codigos) c.alumnaId: c};
                    final sinVincular =
                        alumnas.where((a) => a.activa && !a.vinculada).length;
                    return PageBody(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        InlineNotice(
                          message: sinVincular == 0
                              ? 'Todas las familias tienen cuenta.'
                              : '$sinVincular alumna${sinVincular == 1 ? '' : 's'} '
                                  'sin cuenta de familia. Entrega a cada familia '
                                  'su código: se registra con él en la app.',
                          icon: sinVincular == 0
                              ? Icons.check_circle_outline
                              : Icons.key_outlined,
                          color: sinVincular == 0
                              ? AppColors.success
                              : AppColors.info,
                        ),
                        for (final g in grupos) ...[
                          SectionHeader(
                            g.nombre,
                            subtitle: g.horarioTexto,
                          ),
                          _ListaGrupo(
                            alumnas:
                                alumnas.where((a) => a.grupo == g.id).toList(),
                            codigoDe: codigoDe,
                            onEditar: (a) => _editar(context, grupos, a),
                          ),
                        ],
                        if (alumnas.any(
                            (a) => !grupos.any((g) => g.id == a.grupo))) ...[
                          const SectionHeader('Sin grupo'),
                          _ListaGrupo(
                            alumnas: alumnas
                                .where((a) =>
                                    !grupos.any((g) => g.id == a.grupo))
                                .toList(),
                            codigoDe: codigoDe,
                            onEditar: (a) => _editar(context, grupos, a),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _editar(
    BuildContext context,
    List<Grupo> grupos,
    Alumna? alumna,
  ) async {
    final repo = context.read<ClubRepository>();
    final nombre = TextEditingController(text: alumna?.nombre ?? '');
    final email = TextEditingController(text: alumna?.emailFamilia ?? '');
    var grupo = alumna?.grupo ?? grupos.first.id;
    if (!grupos.any((g) => g.id == grupo)) grupo = grupos.first.id;
    var activa = alumna?.activa ?? true;

    final guardar = await showModalBottomSheet<bool>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                alumna == null ? 'Nueva alumna' : 'Editar alumna',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nombre,
                autofocus: alumna == null,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Nombre y apellidos'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                enabled: alumna?.vinculada != true,
                decoration: const InputDecoration(
                  labelText: 'Email de la familia (opcional)',
                  helperText: 'Si lo pones, sólo ese correo podrá registrarse '
                      'con el código de esta alumna.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: grupo,
                decoration: const InputDecoration(labelText: 'Grupo'),
                items: [
                  for (final g in grupos)
                    DropdownMenuItem(value: g.id, child: Text(g.nombre)),
                ],
                onChanged: (v) => setSheet(() => grupo = v ?? grupo),
              ),
              if (alumna != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activa'),
                  subtitle: const Text(
                    'Si se da de baja, deja de salir en las listas y no se le '
                    'generan cuotas.',
                  ),
                  value: activa,
                  onChanged: (v) => setSheet(() => activa = v),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(alumna == null ? 'Crear y generar código' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (guardar != true || nombre.text.trim().length < 2) return;

    try {
      if (alumna == null) {
        final codigo =
            await repo.crearAlumna(
                nombre: nombre.text, grupo: grupo, emailFamilia: email.text);
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Alumna creada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Entrega este código a la familia para que se '
                      'registre en la app:'),
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    codigo,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: codigo)),
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
        }
      } else {
        await repo.actualizarAlumna(
          alumna.id,
          nombre: nombre.text,
          grupo: grupo,
          activa: activa,
          emailFamilia: alumna.vinculada ? null : email.text,
        );
        if (context.mounted) showAppSnackBar(context, 'Guardado.');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo guardar.', isError: true);
      }
    }
  }
}

class _ListaGrupo extends StatelessWidget {
  const _ListaGrupo({
    required this.alumnas,
    required this.codigoDe,
    required this.onEditar,
  });

  final List<Alumna> alumnas;
  final Map<String, CodigoVinculacion> codigoDe;
  final ValueChanged<Alumna> onEditar;

  @override
  Widget build(BuildContext context) {
    if (alumnas.isEmpty) {
      return Text('Sin alumnas.', style: Theme.of(context).textTheme.bodySmall);
    }
    return CardList(
      children: [
        for (final a in alumnas)
          ListTile(
            title: Text(
              a.nombre,
              style: a.activa
                  ? null
                  : const TextStyle(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
            ),
            subtitle: a.vinculada
                ? const Text('Familia con cuenta')
                : codigoDe[a.id] == null
                    ? const Text('Sin código')
                    : Text.rich(TextSpan(children: [
                        if (a.emailFamilia != null)
                          TextSpan(text: '${a.emailFamilia} · '),
                        const TextSpan(text: 'Código: '),
                        TextSpan(
                          text: codigoDe[a.id]!.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.navy,
                          ),
                        ),
                      ])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!a.activa)
                  const StatusChip(
                    label: 'Baja',
                    color: AppColors.textSecondary,
                  )
                else if (a.vinculada)
                  const StatusChip(
                    label: 'Vinculada',
                    color: AppColors.success,
                    icon: Icons.link,
                  )
                else if (codigoDe[a.id] != null)
                  IconButton(
                    tooltip: 'Copiar código',
                    icon: const Icon(Icons.copy, size: 19),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: codigoDe[a.id]!.codigo),
                      );
                      if (context.mounted) {
                        showAppSnackBar(context, 'Código copiado.');
                      }
                    },
                  ),
              ],
            ),
            onTap: () => onEditar(a),
          ),
      ],
    );
  }
}
