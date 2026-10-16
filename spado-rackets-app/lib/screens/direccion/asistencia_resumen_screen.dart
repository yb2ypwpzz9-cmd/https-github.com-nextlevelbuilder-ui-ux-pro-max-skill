import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/asistencia.dart';
import '../../models/grupo.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../staff/staff_grupos_screen.dart' show MarcaAsistencia;

/// Dirección: asistencia de los últimos 30 días, por grupo y por alumna.
class AsistenciaResumenScreen extends StatelessWidget {
  const AsistenciaResumenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubRepository>();
    final desde =
        claveFecha(DateTime.now().subtract(const Duration(days: 30)));
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia · 30 días')),
      body: StreamView<List<Grupo>>(
        stream: repo.watchGrupos(),
        builder: (context, grupos) => StreamView<List<Alumna>>(
          stream: repo.watchTodasLasAlumnas(),
          builder: (context, alumnas) => StreamView<List<Asistencia>>(
            stream: repo.watchAsistenciaDesde(desde),
            builder: (context, marcas) => PageBody(
              children: [
                BotonExcel(
                  onPressed: () => descargarExcel('asistencia', {
                    'Asistencia': [
                      ['Fecha', 'Grupo', 'Alumna', 'Estado', 'Marcado por'],
                      for (final m in marcas)
                        [
                          m.fecha,
                          grupos.where((g) => g.id == m.grupo).firstOrNull?.nombre ?? m.grupo,
                          m.alumnaNombre,
                          m.estado.label,
                          m.marcadoPorNombre,
                        ],
                    ],
                    'Resumen por alumna': [
                      ['Alumna', 'Grupo', 'Sesiones', 'Asistió', 'Faltas', 'Justificadas', '% asistencia'],
                      for (final a in alumnas.where((a) => a.activa))
                        () {
                          final suyas = marcas.where((m) => m.alumnaId == a.id).toList();
                          int n(EstadoAsistencia e) => suyas.where((m) => m.estado == e).length;
                          return [
                            a.nombre,
                            grupos.where((g) => g.id == a.grupo).firstOrNull?.nombre ?? a.grupo,
                            suyas.length,
                            n(EstadoAsistencia.presente),
                            n(EstadoAsistencia.falta),
                            n(EstadoAsistencia.justificada),
                            suyas.isEmpty ? null : porcentajeAsistencia(suyas),
                          ];
                        }(),
                    ],
                  }),
                ),
                for (final g in grupos.where((g) => g.activo)) ...[
                  Builder(builder: (context) {
                    final delGrupo =
                        marcas.where((m) => m.grupo == g.id).toList();
                    final sesiones = delGrupo.map((m) => m.fecha).toSet();
                    return SectionHeader(
                      g.nombre,
                      subtitle: '${sesiones.length} clases con lista · '
                          '${delGrupo.isEmpty ? '—' : '${porcentajeAsistencia(delGrupo)}%'} asistencia',
                      action: TextButton(
                        onPressed: () => context.push(
                          '/lista/${g.id}?fecha=${claveFecha(DateTime.now())}',
                        ),
                        child: const Text('Pasar lista'),
                      ),
                    );
                  }),
                  CardList(
                    children: [
                      for (final a in alumnas
                          .where((a) => a.grupo == g.id && a.activa))
                        Builder(builder: (context) {
                          final suyas = marcas
                              .where((m) => m.alumnaId == a.id)
                              .toList()
                            ..sort((x, y) => y.fecha.compareTo(x.fecha));
                          final pct = suyas.isEmpty
                              ? null
                              : porcentajeAsistencia(suyas);
                          return ListTile(
                            title: Text(a.nombre),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  for (final m in suyas.take(10).toList().reversed)
                                    MarcaAsistencia(m.estado),
                                  if (suyas.isEmpty)
                                    Text('Sin marcas', style: t.bodySmall),
                                ],
                              ),
                            ),
                            trailing: Text(
                              pct == null ? '—' : '$pct%',
                              style: t.titleMedium?.copyWith(
                                color: pct == null
                                    ? AppColors.textSecondary
                                    : pct >= 80
                                        ? AppColors.success
                                        : pct >= 60
                                            ? AppColors.warning
                                            : AppColors.danger,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
