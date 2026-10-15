import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/grupo.dart';
import '../../models/pago.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Generar los avisos de cuota de un mes: una sola alumna, varias, o todas.
///
/// Cada aviso queda como cuota "Pendiente" en la pestaña Pagos de la familia,
/// con su importe y el plazo (los 5 primeros días del mes). No se envía ningún
/// justificante: la familia paga y sube el suyo, y Dirección lo valida.
class NuevaCuotaScreen extends StatefulWidget {
  const NuevaCuotaScreen({super.key, required this.periodo});
  final String periodo;

  @override
  State<NuevaCuotaScreen> createState() => _NuevaCuotaScreenState();
}

class _NuevaCuotaScreenState extends State<NuevaCuotaScreen> {
  final Set<String> _elegidas = {};
  bool _importeUnico = false;
  final _importe = TextEditingController();
  bool _generando = false;

  late final ClubRepository _repo = context.read<ClubRepository>();
  late final Stream<List<Grupo>> _grupos = _repo.watchGrupos();
  late final Stream<List<Alumna>> _alumnas = _repo.watchTodasLasAlumnas();
  late final Future<Set<String>> _existentes = _repo.idsDeCuotas(widget.periodo);

  @override
  void dispose() {
    _importe.dispose();
    super.dispose();
  }

  Future<void> _generar(List<Alumna> alumnas, List<Grupo> grupos) async {
    final porId = {for (final g in grupos) g.id: g};
    final unico = double.tryParse(_importe.text.replaceAll(',', ''));
    if (_importeUnico && (unico == null || unico <= 0)) {
      showAppSnackBar(context, 'Escribe un importe válido.', isError: true);
      return;
    }
    final cuotas = <CuotaNueva>[
      for (final a in alumnas)
        if (_elegidas.contains(a.id))
          CuotaNueva(
            alumna: a,
            importe: _importeUnico ? unico! : (porId[a.grupo]?.cuotaMensual ?? 0),
            concepto: 'Cuota ${porId[a.grupo]?.nombre ?? 'mensual'}',
          ),
    ];
    if (cuotas.any((c) => c.importe <= 0)) {
      showAppSnackBar(
        context,
        'Algún grupo no tiene cuota asignada. Ponla en Más → Grupos o usa '
        'un importe único.',
        isError: true,
      );
      return;
    }
    setState(() => _generando = true);
    try {
      final n = await _repo.generarCuotas(
        periodo: widget.periodo,
        cuotas: cuotas,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        n == 0
            ? 'Esas alumnas ya tenían cuota este mes.'
            : n == 1
                ? 'Se generó 1 aviso de cuota.'
                : 'Se generaron $n avisos de cuota.',
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _generando = false);
        showAppSnackBar(context, 'No se pudieron generar.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Cuotas de ${etiquetaPeriodo(widget.periodo)}')),
      body: StreamView<List<Grupo>>(
        stream: _grupos,
        builder: (context, grupos) => StreamView<List<Alumna>>(
          stream: _alumnas,
          builder: (context, todas) => FutureBuilder<Set<String>>(
            future: _existentes,
            builder: (context, snap) {
              if (!snap.hasData) return const LoadingView();
              final ya = snap.data!;
              final alumnas = todas.where((a) => a.activa).toList();
              bool tiene(Alumna a) =>
                  ya.contains(Pago.idPara(a.id, widget.periodo));
              final disponibles = alumnas.where((a) => !tiene(a)).toList();
              final elegidas =
                  disponibles.where((a) => _elegidas.contains(a.id)).length;

              return Column(
                children: [
                  Expanded(
                    child: PageBody(
                      children: [
                        const InlineNotice(
                          message: 'Elige las alumnas a las que quieres '
                              'generar la cuota. Aparece en la pestaña Pagos '
                              'de su familia con el importe y el plazo (hasta '
                              'el día 5).',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('Todas las que faltan'),
                              onPressed: () => setState(() => _elegidas
                                ..clear()
                                ..addAll(disponibles.map((a) => a.id))),
                            ),
                            ActionChip(
                              label: const Text('Ninguna'),
                              onPressed: () =>
                                  setState(() => _elegidas.clear()),
                            ),
                          ],
                        ),
                        for (final g in grupos.where((g) => g.activo)) ...[
                          Builder(builder: (context) {
                            final delGrupo = alumnas
                                .where((a) => a.grupo == g.id)
                                .toList();
                            final libres =
                                delGrupo.where((a) => !tiene(a)).toList();
                            final todasElegidas = libres.isNotEmpty &&
                                libres.every((a) => _elegidas.contains(a.id));
                            return SectionHeader(
                              g.nombre,
                              subtitle: formatoImporte(
                                  g.cuotaMensual, g.moneda),
                              action: libres.isEmpty
                                  ? null
                                  : TextButton(
                                      onPressed: () => setState(() {
                                        for (final a in libres) {
                                          todasElegidas
                                              ? _elegidas.remove(a.id)
                                              : _elegidas.add(a.id);
                                        }
                                      }),
                                      child: Text(todasElegidas
                                          ? 'Quitar grupo'
                                          : 'Elegir grupo'),
                                    ),
                            );
                          }),
                          CardList(
                            children: [
                              for (final a
                                  in alumnas.where((a) => a.grupo == g.id))
                                CheckboxListTile(
                                  value: tiene(a) || _elegidas.contains(a.id),
                                  onChanged: tiene(a)
                                      ? null
                                      : (v) => setState(() => v == true
                                          ? _elegidas.add(a.id)
                                          : _elegidas.remove(a.id)),
                                  title: Text(a.nombre),
                                  subtitle: Text(tiene(a)
                                      ? 'Ya tiene cuota este mes'
                                      : a.vinculada
                                          ? 'Familia con cuenta'
                                          : 'Familia aún sin cuenta: verá la '
                                              'cuota al registrarse'),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                            ],
                          ),
                        ],
                        const SectionHeader('Importe'),
                        Card(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('Cuota de cada grupo'),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('Mismo importe'),
                                    ),
                                  ],
                                  selected: {_importeUnico},
                                  showSelectedIcon: false,
                                  onSelectionChanged: (v) =>
                                      setState(() => _importeUnico = v.first),
                                ),
                              ),
                              if (_importeUnico)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                                  child: TextField(
                                    controller: _importe,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Importe',
                                      prefixText: 'RD\$ ',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Las cuotas que ya existen no se modifican.',
                          style: t.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 728),
                          child: FilledButton(
                            onPressed: _generando || elegidas == 0
                                ? null
                                : () => _generar(alumnas, grupos),
                            child: Text(_generando
                                ? 'Generando…'
                                : elegidas == 0
                                    ? 'Elige alumnas'
                                    : elegidas == 1
                                        ? 'Generar 1 aviso de cuota'
                                        : 'Generar $elegidas avisos de cuota'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
