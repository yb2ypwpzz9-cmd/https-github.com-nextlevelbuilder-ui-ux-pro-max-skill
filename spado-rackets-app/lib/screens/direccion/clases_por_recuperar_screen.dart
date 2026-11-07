import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asistencia.dart' show claveFecha, fechaDeClave;
import '../../models/clase_anulada.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Clases que no se pudieron dar (mal tiempo, pista, entrenador…) y cuánto
/// falta por recuperar de cada persona.
class ClasesPorRecuperarScreen extends StatefulWidget {
  const ClasesPorRecuperarScreen({super.key});

  @override
  State<ClasesPorRecuperarScreen> createState() =>
      _ClasesPorRecuperarScreenState();
}

class _ClasesPorRecuperarScreenState extends State<ClasesPorRecuperarScreen> {
  late final ClubRepository _repo = context.read<ClubRepository>();
  bool _soloPendientes = true;

  // Seis meses hacia atrás: lo anterior ya no suele reclamarse.
  late final Stream<List<ClaseAnulada>> _anuladas = _repo.watchAnuladasDesde(
      claveFecha(DateTime.now().subtract(const Duration(days: 183))));

  Future<void> _recuperar(ClaseAnulada c) async {
    final controlador = TextEditingController(text: '${c.pendientes}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recuperación de ${c.alumnaNombre.split(' ').first}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pendiente: ${duracionTexto(c.pendientes)}'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controlador,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos recuperados',
                suffixText: 'min',
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final minutos = int.tryParse(controlador.text.trim());
    controlador.dispose();
    if (ok != true) return;
    if (minutos == null || minutos <= 0) {
      if (mounted) {
        showAppSnackBar(context, 'Escribe los minutos recuperados.',
            isError: true);
      }
      return;
    }
    try {
      await _repo.registrarRecuperacion(c, minutos);
      if (mounted) showAppSnackBar(context, 'Recuperación guardada.');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo guardar.', isError: true);
      }
    }
  }

  Future<void> _eliminar(ClaseAnulada c) async {
    final ok = await confirmar(
      context,
      titulo: 'Quitar esta anulación',
      mensaje: 'La clase de ${c.alumnaNombre} del '
          '${fechaFormat.format(fechaDeClave(c.fecha))} vuelve a contar como '
          'clase normal. Úsalo solo si te equivocaste.',
      accion: 'Quitar',
      peligrosa: true,
    );
    if (!ok) return;
    try {
      await _repo.eliminarAnulada(c.id);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo quitar.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Clases por recuperar')),
      body: StreamView<List<ClaseAnulada>>(
        stream: _anuladas,
        builder: (context, todas) {
          final visibles =
              _soloPendientes ? todas.where((c) => !c.recuperada).toList() : todas;
          final porPersona = <String, List<ClaseAnulada>>{};
          for (final c in visibles) {
            (porPersona[c.alumnaId] ??= []).add(c);
          }
          final personas = porPersona.values.toList()
            ..sort((a, b) {
              final pa = a.fold<int>(0, (s, c) => s + c.pendientes);
              final pb = b.fold<int>(0, (s, c) => s + c.pendientes);
              return pb.compareTo(pa);
            });
          final totalPendiente =
              todas.fold<int>(0, (s, c) => s + c.pendientes);

          return PageBody(
            children: [
              KpiGrid(children: [
                KpiTile(
                  valor: duracionTexto(totalPendiente),
                  etiqueta: 'Por recuperar en total',
                  icon: Icons.schedule,
                  color: totalPendiente == 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
                KpiTile(
                  valor: '${todas.where((c) => !c.recuperada).map((c) => c.alumnaId).toSet().length}',
                  etiqueta: 'Personas con clases pendientes',
                  icon: Icons.groups_outlined,
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Solo lo pendiente'),
                value: _soloPendientes,
                onChanged: (v) => setState(() => _soloPendientes = v),
              ),
              BotonExcel(
                onPressed: () => descargarExcel('clases-anuladas', {
                  'Clases anuladas': [
                    [
                      'Fecha',
                      'Nombre',
                      'Motivo',
                      'Minutos anulados',
                      'Minutos recuperados',
                      'Minutos pendientes',
                      'Nota',
                      'Anulada por',
                    ],
                    for (final c in todas)
                      [
                        c.fecha,
                        c.alumnaNombre,
                        c.motivo.etiqueta,
                        c.minutos,
                        c.recuperados,
                        c.pendientes,
                        c.nota,
                        c.creadoPorNombre,
                      ],
                  ],
                  'Pendiente por persona': [
                    ['Nombre', 'Minutos pendientes', 'Horas pendientes'],
                    for (final grupo in (() {
                      final m = <String, List<ClaseAnulada>>{};
                      for (final c in todas) {
                        (m[c.alumnaId] ??= []).add(c);
                      }
                      return m.values;
                    })())
                      [
                        grupo.first.alumnaNombre,
                        grupo.fold<int>(0, (s, c) => s + c.pendientes),
                        (grupo.fold<int>(0, (s, c) => s + c.pendientes) / 60)
                            .toStringAsFixed(1),
                      ],
                  ],
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (personas.isEmpty)
                const EmptyState(
                  compacto: true,
                  icon: Icons.event_available_outlined,
                  title: 'No hay clases por recuperar',
                  message: 'Cuando se anule una clase desde "Pasar lista", '
                      'aparecerá aquí.',
                )
              else
                for (final lista in personas) ...[
                  SectionHeader(
                    lista.first.alumnaNombre,
                    subtitle: 'Pendiente: ${duracionTexto(lista.fold<int>(0, (s, c) => s + c.pendientes))}',
                  ),
                  CardList(
                    children: [
                      for (final c in lista)
                        ListTile(
                          title: Text(
                            '${capitalizar(fechaCortaFormat.format(fechaDeClave(c.fecha)))} · '
                            '${c.motivo.etiqueta}',
                          ),
                          subtitle: Text(
                            'Anulado ${duracionTexto(c.minutos)}'
                            '${c.recuperados > 0 ? ' · recuperado ${duracionTexto(c.recuperados)}' : ''}'
                            '${c.nota.isEmpty ? '' : '\n${c.nota}'}',
                          ),
                          isThreeLine: c.nota.isNotEmpty,
                          trailing: c.recuperada
                              ? const StatusChip(
                                  label: 'Recuperada',
                                  color: AppColors.success,
                                  icon: Icons.check,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(duracionTexto(c.pendientes),
                                        style: t.titleSmall),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Registrar recuperación',
                                      icon: const Icon(Icons.task_alt,
                                          color: AppColors.success),
                                      onPressed: () => _recuperar(c),
                                    ),
                                  ],
                                ),
                          onLongPress: () => _eliminar(c),
                        ),
                    ],
                  ),
                ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Mantén pulsada una fila para quitar una anulación hecha por '
                'error.',
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
