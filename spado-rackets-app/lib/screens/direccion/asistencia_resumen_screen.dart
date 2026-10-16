import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/asistencia.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/foto_alumna.dart';
import '../staff/staff_grupos_screen.dart' show MarcaAsistencia;

/// Dirección: asistencia de los últimos 30 días de cada persona.
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
      body: StreamView<List<Alumna>>(
        stream: repo.watchTodasLasAlumnas(),
        builder: (context, todas) => StreamView<List<Asistencia>>(
          stream: repo.watchAsistenciaDesde(desde),
          builder: (context, marcas) {
            final alumnas = todas.where((a) => a.activa).toList()
              ..sort((a, b) => a.nombre.compareTo(b.nombre));
            return PageBody(
              children: [
                BotonExcel(
                  onPressed: () => descargarExcel('asistencia', {
                    'Asistencia': [
                      ['Fecha', 'Nombre', 'Estado', 'Marcado por'],
                      for (final m in marcas)
                        [
                          m.fecha,
                          m.alumnaNombre,
                          m.estado.label,
                          m.marcadoPorNombre,
                        ],
                    ],
                    'Resumen por persona': [
                      [
                        'Nombre',
                        'Sesiones',
                        'Asistió',
                        'Faltas',
                        'Justificadas',
                        '% asistencia',
                      ],
                      for (final a in alumnas)
                        () {
                          final suyas =
                              marcas.where((m) => m.alumnaId == a.id).toList();
                          int n(EstadoAsistencia e) =>
                              suyas.where((m) => m.estado == e).length;
                          return [
                            a.nombre,
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
                SectionHeader(
                  'Todo el alumnado',
                  subtitle:
                      '${marcas.map((m) => m.fecha).toSet().length} días con '
                      'lista · ${marcas.isEmpty ? '—' : '${porcentajeAsistencia(marcas)}%'} '
                      'de asistencia',
                  action: TextButton(
                    onPressed: () => context
                        .push('/lista?fecha=${claveFecha(DateTime.now())}'),
                    child: const Text('Pasar lista'),
                  ),
                ),
                CardList(
                  children: [
                    for (final a in alumnas)
                      Builder(builder: (context) {
                        final suyas = marcas
                            .where((m) => m.alumnaId == a.id)
                            .toList()
                          ..sort((x, y) => y.fecha.compareTo(x.fecha));
                        final pct =
                            suyas.isEmpty ? null : porcentajeAsistencia(suyas);
                        return ListTile(
                          leading: FotoAlumna(a, size: 40),
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
            );
          },
        ),
      ),
    );
  }
}
