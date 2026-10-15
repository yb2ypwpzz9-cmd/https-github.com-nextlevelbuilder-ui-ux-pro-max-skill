import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/club_config.dart';
import '../../models/grupo.dart';
import '../../models/pago.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Grupos de entrenamiento: días, hora, pista y cuota mensual.
class GruposScreen extends StatelessWidget {
  const GruposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos y cuotas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => editarGrupo(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
      body: StreamView<List<Grupo>>(
        stream: context.read<ClubRepository>().watchGrupos(),
        builder: (context, grupos) {
          if (grupos.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aún no hay grupos',
              message: 'Crea el primero con el botón de abajo.',
            );
          }
          return PageBody(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              CardList(
                children: [
                  for (final g in grupos)
                    ListTile(
                      title: Text(g.nombre),
                      subtitle: Text('${g.deporte} · ${g.horarioTexto}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatoImporte(g.cuotaMensual, g.moneda),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          if (!g.activo)
                            const Text(
                              'Inactivo',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => editarGrupo(context, g),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> editarGrupo(BuildContext context, Grupo? grupo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FormGrupo(grupo: grupo, raiz: context),
  );
}

class _FormGrupo extends StatefulWidget {
  const _FormGrupo({required this.grupo, required this.raiz});
  final Grupo? grupo;
  final BuildContext raiz;

  @override
  State<_FormGrupo> createState() => _FormGrupoState();
}

class _FormGrupoState extends State<_FormGrupo> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.grupo?.nombre);
  late final _pista = TextEditingController(text: widget.grupo?.pista);
  late final _cuota = TextEditingController(
    text: widget.grupo == null || widget.grupo!.cuotaMensual == 0
        ? ''
        : widget.grupo!.cuotaMensual.toStringAsFixed(0),
  );
  late String _deporte = widget.grupo?.deporte ?? 'Tenis';
  late final Set<int> _dias = {...?widget.grupo?.dias};
  late TimeOfDay? _hora = _parseHora(widget.grupo?.horaInicio);
  late int _duracion = widget.grupo?.duracionMinutos ?? 60;
  late Moneda _moneda = widget.grupo?.moneda ?? ClubConfig.monedaPorDefecto;
  late bool _activo = widget.grupo?.activo ?? true;
  bool _guardando = false;

  static TimeOfDay? _parseHora(String? h) {
    final p = (h ?? '').split(':');
    if (p.length != 2) return null;
    final hh = int.tryParse(p[0]);
    final mm = int.tryParse(p[1]);
    if (hh == null || mm == null) return null;
    return TimeOfDay(hour: hh, minute: mm);
  }

  String get _horaTexto => _hora == null
      ? ''
      : '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_dias.isEmpty) {
      showAppSnackBar(context, 'Elige al menos un día de clase.', isError: true);
      return;
    }
    setState(() => _guardando = true);
    final g = Grupo(
      id: widget.grupo?.id ?? '',
      nombre: _nombre.text.trim(),
      deporte: _deporte,
      dias: _dias.toList()..sort(),
      horaInicio: _horaTexto,
      duracionMinutos: _duracion,
      pista: _pista.text.trim(),
      cuotaMensual: double.tryParse(_cuota.text.replaceAll(',', '')) ?? 0,
      moneda: _moneda,
      activo: _activo,
    );
    try {
      await context
          .read<ClubRepository>()
          .guardarGrupo(g, nuevo: widget.grupo == null);
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.raiz.mounted) showAppSnackBar(widget.raiz, 'Grupo guardado.');
    } catch (_) {
      if (mounted) {
        setState(() => _guardando = false);
        showAppSnackBar(context, 'No se pudo guardar.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.grupo == null ? 'Nuevo grupo' : 'Editar grupo',
                style: t.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Tenis Iniciación 6-9 años',
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Pon un nombre' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Tenis', label: Text('Tenis')),
                  ButtonSegment(value: 'Pádel', label: Text('Pádel')),
                  ButtonSegment(value: 'Pickleball', label: Text('Pickleball')),
                ],
                selected: {_deporte},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _deporte = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Días de clase', style: t.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(Grupo.nombresDias[d - 1]),
                      selected: _dias.contains(d),
                      onSelected: (v) => setState(
                          () => v ? _dias.add(d) : _dias.remove(d)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final h = await showTimePicker(
                          context: context,
                          initialTime: _hora ??
                              const TimeOfDay(hour: 17, minute: 0),
                        );
                        if (h != null) setState(() => _hora = h);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(_hora == null ? 'Hora' : _horaTexto),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _duracion,
                      decoration: const InputDecoration(labelText: 'Duración'),
                      items: const [
                        DropdownMenuItem(value: 45, child: Text('45 min')),
                        DropdownMenuItem(value: 60, child: Text('1 h')),
                        DropdownMenuItem(value: 90, child: Text('1 h 30')),
                        DropdownMenuItem(value: 120, child: Text('2 h')),
                      ],
                      onChanged: (v) => setState(() => _duracion = v ?? 60),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _pista,
                decoration: const InputDecoration(
                  labelText: 'Pista (opcional)',
                  hintText: 'Ej. Pista 2',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cuota,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Cuota mensual'),
                      validator: (v) {
                        final n =
                            double.tryParse((v ?? '').replaceAll(',', ''));
                        return n == null || n < 0 ? 'Importe no válido' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Moneda>(
                      initialValue: _moneda,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: [
                        for (final m in Moneda.values)
                          DropdownMenuItem(value: m, child: Text(m.simbolo)),
                      ],
                      onChanged: (v) => setState(() => _moneda = v ?? _moneda),
                    ),
                  ),
                ],
              ),
              if (widget.grupo != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Grupo activo'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando…' : 'Guardar grupo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
