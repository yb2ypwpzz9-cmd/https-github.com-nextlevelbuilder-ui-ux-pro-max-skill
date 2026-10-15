import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/jornada.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../app_shell.dart';

enum _Periodo { semana, mes, mesAnterior }

/// Registro de jornada del staff: horas por persona y cada fichaje con su
/// ubicación. Los fichajes no se pueden editar desde la app.
class FichajesScreen extends StatefulWidget {
  const FichajesScreen({super.key});

  @override
  State<FichajesScreen> createState() => _FichajesScreenState();
}

class _FichajesScreenState extends State<FichajesScreen> {
  _Periodo _periodo = _Periodo.semana;
  String? _persona;

  (DateTime, DateTime) get _rango {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    return switch (_periodo) {
      _Periodo.semana => (
          inicioDia.subtract(Duration(days: hoy.weekday - 1)),
          inicioDia.add(const Duration(days: 1)),
        ),
      _Periodo.mes => (
          DateTime(hoy.year, hoy.month),
          inicioDia.add(const Duration(days: 1)),
        ),
      _Periodo.mesAnterior => (
          DateTime(hoy.year, hoy.month - 1),
          DateTime(hoy.year, hoy.month),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (desde, hasta) = _rango;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const TabAppBar(title: 'Fichajes de entrenadores'),
      body: StreamView<List<Jornada>>(
        stream: context.read<ClubRepository>().watchJornadasDesde(desde),
        builder: (context, todas) {
          final enRango =
              todas.where((j) => j.entrada.isBefore(hasta)).toList();
          final personas = <String, String>{
            for (final j in enRango) j.staffUid: j.staffNombre,
          };
          final lista = _persona == null
              ? enRango
              : enRango.where((j) => j.staffUid == _persona).toList();

          return PageBody(
            children: [
              SegmentedButton<_Periodo>(
                segments: const [
                  ButtonSegment(value: _Periodo.semana, label: Text('Semana')),
                  ButtonSegment(value: _Periodo.mes, label: Text('Este mes')),
                  ButtonSegment(
                    value: _Periodo.mesAnterior,
                    label: Text('Mes anterior'),
                  ),
                ],
                selected: {_periodo},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _periodo = s.first),
              ),
              const SectionHeader('Días fichados por persona'),
              if (personas.isEmpty)
                const EmptyState(
                  compacto: true,
                  icon: Icons.badge_outlined,
                  title: 'Sin fichajes en este periodo',
                )
              else
                CardList(
                  children: [
                    for (final e in personas.entries)
                      Builder(builder: (context) {
                        final suyas =
                            enRango.where((j) => j.staffUid == e.key).toList();
                        final dias = suyas
                            .map((j) => DateTime(
                                j.entrada.year, j.entrada.month, j.entrada.day))
                            .toSet()
                            .length;
                        return ListTile(
                          selected: _persona == e.key,
                          selectedTileColor:
                              AppColors.navy.withValues(alpha: 0.05),
                          leading: Avatar(
                            e.value
                                .split(' ')
                                .take(2)
                                .map((p) => p.isEmpty ? '' : p[0])
                                .join()
                                .toUpperCase(),
                          ),
                          title: Text(e.value),
                          subtitle: const Text('Días fichados'),
                          trailing: Text(
                            '$dias',
                            style: t.titleMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          onTap: () => setState(() =>
                              _persona = _persona == e.key ? null : e.key),
                        );
                      }),
                  ],
                ),
              SectionHeader(
                _persona == null ? 'Todos los fichajes' : personas[_persona]!,
                subtitle: _persona == null
                    ? 'Toca una persona para filtrar'
                    : 'Toca de nuevo a la persona para ver a todos',
              ),
              if (lista.isNotEmpty)
                CardList(children: [for (final j in lista) _FilaFichaje(j)]),
            ],
          );
        },
      ),
    );
  }
}

class _FilaFichaje extends StatelessWidget {
  const _FilaFichaje(this.j);
  final Jornada j;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        '${j.staffNombre} · ${capitalizar(fechaCortaFormat.format(j.entrada))}',
      ),
      subtitle: Text(
        'Llegada ${horaFormat.format(j.entrada)}'
        '${j.entradaConUbicacion ? '' : ' · sin ubicación'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (j.mapaEntrada != null)
            IconButton(
              tooltip: 'Ver ubicación de entrada',
              icon: const Icon(Icons.place_outlined, color: AppColors.navy),
              onPressed: () =>
                  launchUrl(j.mapaEntrada!, webOnlyWindowName: '_blank'),
            ),
        ],
      ),
    );
  }
}
