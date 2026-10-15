import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/asistencia.dart';
import '../../models/grupo.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../app_shell.dart';

/// Los grupos del entrenador: alumnas, % de asistencia y pase de lista de
/// cualquier fecha.
class StaffGruposScreen extends StatelessWidget {
  const StaffGruposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();
    return Scaffold(
      appBar: const TabAppBar(title: 'Mis grupos'),
      body: StreamView<List<Grupo>>(
        stream: repo.watchGrupos(),
        builder: (context, grupos) {
          final mios =
              grupos.where((g) => user.grupos.contains(g.id)).toList();
          if (mios.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aún no tienes grupos asignados',
              message: 'Dirección te los asigna desde "Equipo".',
            );
          }
          return StreamView<List<Alumna>>(
            stream: repo.watchAlumnasDeGrupos(mios.map((g) => g.id).toList()),
            builder: (context, alumnas) => PageBody(
              children: [
                for (final g in mios) ...[
                  _TarjetaGrupo(
                    grupo: g,
                    alumnas: alumnas
                        .where((a) => a.grupo == g.id && a.activa)
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaGrupo extends StatelessWidget {
  const _TarjetaGrupo({required this.grupo, required this.alumnas});
  final Grupo grupo;
  final List<Alumna> alumnas;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hace30 = claveFecha(DateTime.now().subtract(const Duration(days: 30)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: StreamBuilder<List<Asistencia>>(
          stream: context
              .read<ClubRepository>()
              .watchAsistenciaGrupo(grupo.id, hace30),
          builder: (context, snap) {
            final marcas = snap.data ?? const <Asistencia>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(grupo.nombre, style: t.titleLarge),
                          Text(grupo.horarioTexto, style: t.bodySmall),
                        ],
                      ),
                    ),
                    if (marcas.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${porcentajeAsistencia(marcas)}%',
                            style: t.headlineSmall,
                          ),
                          Text('asistencia 30 días', style: t.labelSmall),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final a in alumnas)
                  _FilaResumen(
                    alumna: a,
                    marcas: marcas.where((m) => m.alumnaId == a.id).toList(),
                  ),
                if (alumnas.isEmpty)
                  Text('Sin alumnas todavía.', style: t.bodySmall),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.push(
                    '/lista/${grupo.id}?fecha=${claveFecha(DateTime.now())}',
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Pasar lista'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Nombre, % y las últimas marcas como fichas de color con letra.
class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.alumna, required this.marcas});
  final Alumna alumna;
  final List<Asistencia> marcas;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ultimas = marcas.take(8).toList().reversed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(alumna.nombre, style: t.bodyMedium)),
          for (final m in ultimas) MarcaAsistencia(m.estado),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              marcas.isEmpty ? '—' : '${porcentajeAsistencia(marcas)}%',
              textAlign: TextAlign.right,
              style: t.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class MarcaAsistencia extends StatelessWidget {
  const MarcaAsistencia(this.estado, {super.key});
  final EstadoAsistencia estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      EstadoAsistencia.presente => AppColors.success,
      EstadoAsistencia.falta => AppColors.danger,
      EstadoAsistencia.justificada => AppColors.warning,
    };
    return Tooltip(
      message: estado.label,
      child: Container(
        margin: const EdgeInsets.only(left: 3),
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          estado.letra,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
