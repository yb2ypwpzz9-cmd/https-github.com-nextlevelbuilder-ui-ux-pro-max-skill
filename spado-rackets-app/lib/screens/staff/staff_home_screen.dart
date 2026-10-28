import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/asistencia.dart';
import '../../models/cambio_clase.dart';
import '../../models/jornada.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/aviso_notificaciones.dart';
import '../../widgets/fichaje_panel.dart';
import '../../widgets/foto_alumna.dart';
import '../app_shell.dart';

/// "Hoy" del staff: fichar, y las clases del día con su lista.
class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();
    final hoy = DateTime.now();
    final lunes = DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(Duration(days: hoy.weekday - 1));

    return Scaffold(
      appBar: const TabAppBar(title: 'Hoy'),
      body: PageBody(
        children: [
          Text(
            'Hola, ${user.nombreVisible.split(' ').first}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          const FichajePanel(),
          SectionHeader(
            'Clases de hoy',
            subtitle: capitalizar(fechaLargaFormat.format(hoy)),
          ),
          if (user.grupos.isEmpty)
            const EmptyState(
              compacto: true,
              icon: Icons.groups_outlined,
              title: 'Todavía no hay alumnado',
              message: 'Aparecerá cuando Dirección dé de alta a las primeras '
                  'fichas.',
            )
          else
            StreamView<List<Alumna>>(
              streamKey: user.grupos.join(','),
              stream: repo.watchAlumnasDeGrupos(user.grupos),
              builder: (context, todas) => StreamView<List<CambioClase>>(
              streamKey: claveFecha(hoy),
              stream: repo.watchCambiosDia(claveFecha(hoy),
                  grupos: user.grupos),
              builder: (context, lista) {
                final cambios = {for (final c in lista) c.alumnaId: c};
                String horaDe(Alumna a) =>
                    claseDelDia(a, hoy, cambios[a.id])?.hora ?? a.horaInicio;
                final deHoy = todas
                    .where((a) =>
                        a.activa && claseDelDia(a, hoy, cambios[a.id]) != null)
                    .toList()
                  ..sort((a, b) => horaDe(a).compareTo(horaDe(b)));
                if (deHoy.isEmpty) {
                  return const EmptyState(
                    compacto: true,
                    icon: Icons.event_available_outlined,
                    title: 'Hoy no hay clases',
                    message: 'Puedes pasar lista de otro día desde '
                        '"Alumnado".',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CardList(
                      children: [
                        for (final a in deHoy)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 4,
                            ),
                            leading: _HoraBloque(
                              hora: horaDe(a).isEmpty
                                  ? ''
                                  : formatoHora12(horaDe(a)),
                            ),
                            title: Text(
                              a.nombre,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            trailing: FotoAlumna(a, size: 38),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: () => context
                          .push('/lista?fecha=${claveFecha(hoy)}'),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text('Pasar lista (${deHoy.length})'),
                    ),
                  ],
                );
              },
            ),
          ),
          const SectionHeader('Mis fichajes'),
          StreamView<List<Jornada>>(
            streamKey: '${user.uid}${hoy.year}${hoy.month}${hoy.day}',
            stream: repo.watchMisJornadas(
              user.uid,
              DateTime(hoy.year, hoy.month, 1).isBefore(lunes)
                  ? DateTime(hoy.year, hoy.month, 1)
                  : lunes,
            ),
            builder: (context, jornadas) {
              final semana = jornadas.where((j) => !j.entrada.isBefore(lunes));
              final mes = jornadas.where((j) =>
                  j.entrada.month == hoy.month && j.entrada.year == hoy.year);
              return Column(
                children: [
                  KpiGrid(children: [
                    KpiTile(
                      valor: '${semana.length}',
                      etiqueta: 'Días fichados esta semana',
                      icon: Icons.date_range_outlined,
                    ),
                    KpiTile(
                      valor: '${mes.length}',
                      etiqueta: 'Días fichados este mes',
                      icon: Icons.calendar_month_outlined,
                    ),
                  ]),
                  if (jornadas.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CardList(
                      children: [
                        for (final j in jornadas.take(6)) _FilaJornada(j),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          // Al final: si aparece tarde, no empuja lo que ya se va a pulsar.
          const SizedBox(height: AppSpacing.md),
          const AvisoNotificaciones(),
        ],
      ),
    );
  }
}

class _HoraBloque extends StatelessWidget {
  const _HoraBloque({required this.hora});
  final String hora;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        hora.isEmpty ? '—' : hora,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _FilaJornada extends StatelessWidget {
  const _FilaJornada(this.j);
  final Jornada j;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(capitalizar(fechaCortaFormat.format(j.entrada))),
      trailing: Text(
        'Llegada ${horaFormat.format(j.entrada)}',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
