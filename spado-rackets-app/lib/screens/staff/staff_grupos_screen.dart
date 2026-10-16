import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/asistencia.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/contacto.dart';
import '../../widgets/foto_alumna.dart';
import '../app_shell.dart';

/// Alumnado del entrenador: cada persona con su horario, su asistencia de los
/// últimos 30 días y el acceso al pase de lista.
class StaffGruposScreen extends StatelessWidget {
  const StaffGruposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();
    final desde = claveFecha(DateTime.now().subtract(const Duration(days: 30)));
    return Scaffold(
      appBar: const TabAppBar(title: 'Alumnado'),
      body: user.grupos.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aún no hay alumnado visible',
              message: 'Aparecerá cuando Dirección dé de alta a las primeras '
                  'fichas.',
            )
          : StreamView<List<Alumna>>(
              streamKey: user.grupos.join(','),
              stream: repo.watchAlumnasDeGrupos(user.grupos),
              builder: (context, todas) => StreamView<List<Asistencia>>(
                streamKey: user.grupos.join(','),
                stream: repo.watchAsistenciaDeGrupos(user.grupos, desde),
                builder: (context, marcas) {
                  final alumnas = todas.where((a) => a.activa).toList()
                    ..sort((a, b) => a.nombre.compareTo(b.nombre));
                  return PageBody(
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push(
                          '/lista?fecha=${claveFecha(DateTime.now())}',
                        ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Pasar lista de hoy'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (alumnas.isEmpty)
                        const EmptyState(
                          compacto: true,
                          icon: Icons.person_off_outlined,
                          title: 'Todavía no hay alumnado',
                        )
                      else
                        CardList(
                          children: [
                            for (final a in alumnas)
                              _FilaResumen(
                                alumna: a,
                                marcas: marcas
                                    .where((m) => m.alumnaId == a.id)
                                    .toList(),
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
}

/// Foto, nombre, horario, % y las últimas marcas como fichas con letra.
class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.alumna, required this.marcas});
  final Alumna alumna;
  final List<Asistencia> marcas;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ultimas = marcas.take(6).toList().reversed;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 10),
      child: Row(
        children: [
          FotoAlumna(alumna, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alumna.nombre, style: t.titleSmall),
                Text(
                  [
                    alumna.horarioTexto,
                    if (alumna.contactoNombre != null) alumna.contactoNombre!,
                  ].join(' · '),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          if (alumna.contactoTelefono != null)
            BotonesContacto(alumna.contactoTelefono!),
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
