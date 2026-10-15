import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/asistencia.dart';
import '../../models/grupo.dart';
import '../../models/jornada.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fichaje_panel.dart';
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
          StreamView<List<Grupo>>(
            stream: repo.watchGrupos(),
            builder: (context, grupos) {
              final mios = grupos
                  .where((g) => user.grupos.contains(g.id) && g.activo)
                  .toList();
              if (mios.isEmpty) {
                return const EmptyState(
                  compacto: true,
                  icon: Icons.groups_outlined,
                  title: 'Aún no tienes grupos asignados',
                  message: 'Dirección te los asigna desde "Equipo".',
                );
              }
              final deHoy = mios.where((g) => g.tieneClaseEl(hoy)).toList()
                ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
              if (deHoy.isEmpty) {
                return const EmptyState(
                  compacto: true,
                  icon: Icons.event_available_outlined,
                  title: 'Hoy no tienes clases',
                  message: 'Puedes pasar lista de otro día desde "Grupos".',
                );
              }
              return CardList(
                children: [
                  for (final g in deHoy) _ClaseDeHoy(grupo: g, fecha: hoy),
                ],
              );
            },
          ),
          const SectionHeader('Mis horas'),
          StreamView<List<Jornada>>(
            stream: repo.watchMisJornadas(
              user.uid,
              DateTime(hoy.year, hoy.month, 1).isBefore(lunes)
                  ? DateTime(hoy.year, hoy.month, 1)
                  : lunes,
            ),
            builder: (context, jornadas) {
              final ahora = DateTime.now();
              final semana = jornadas.where((j) => !j.entrada.isBefore(lunes));
              final mes = jornadas.where((j) =>
                  j.entrada.month == hoy.month && j.entrada.year == hoy.year);
              return Column(
                children: [
                  KpiGrid(children: [
                    KpiTile(
                      valor: formatoDuracion(totalTrabajado(semana, ahora)),
                      etiqueta: 'Esta semana',
                      icon: Icons.date_range_outlined,
                    ),
                    KpiTile(
                      valor: formatoDuracion(totalTrabajado(mes, ahora)),
                      etiqueta: 'Este mes',
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
        ],
      ),
    );
  }
}

class _ClaseDeHoy extends StatelessWidget {
  const _ClaseDeHoy({required this.grupo, required this.fecha});
  final Grupo grupo;
  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final clave = claveFecha(fecha);
    return StreamBuilder<List<Asistencia>>(
      stream: context.read<ClubRepository>().watchSesion(grupo.id, clave),
      builder: (context, snap) {
        final hecha = (snap.data ?? const []).isNotEmpty;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          leading: _HoraBloque(hora: grupo.horaInicio),
          title: Text(grupo.nombre, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(
            [grupo.deporte, if (grupo.pista.isNotEmpty) grupo.pista].join(' · '),
          ),
          trailing: hecha
              ? const StatusChip(
                  label: 'Lista hecha',
                  color: AppColors.success,
                  icon: Icons.check,
                )
              : FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () =>
                      context.push('/lista/${grupo.id}?fecha=$clave'),
                  child: const Text('Pasar lista'),
                ),
          onTap: () => context.push('/lista/${grupo.id}?fecha=$clave'),
        );
      },
    );
  }
}

class _HoraBloque extends StatelessWidget {
  const _HoraBloque({required this.hora});
  final String hora;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
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
      subtitle: Text(
        '${horaFormat.format(j.entrada)} → '
        '${j.salida == null ? 'en curso' : horaFormat.format(j.salida!)}',
      ),
      trailing: Text(
        formatoDuracion(j.duracionHasta(DateTime.now())),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
