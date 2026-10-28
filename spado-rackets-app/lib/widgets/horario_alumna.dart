import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumna.dart';
import '../models/asistencia.dart' show claveFecha, fechaDeClave;
import '../models/cambio_clase.dart';
import '../services/auth_service.dart';
import '../models/grupo.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Hora en formato digital (escribir "5" y "30" y elegir AM o PM), más fácil
/// en el móvil que arrastrar las agujas de un reloj.
Future<TimeOfDay?> elegirHoraDigital(
  BuildContext context,
  TimeOfDay? inicial,
) =>
    showTimePicker(
      context: context,
      initialTime: inicial ?? const TimeOfDay(hour: 17, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Hora de la clase',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );

TimeOfDay? horaDeTexto(String? h) {
  final p = (h ?? '').split(':');
  if (p.length != 2) return null;
  final hh = int.tryParse(p[0]);
  final mm = int.tryParse(p[1]);
  if (hh == null || mm == null) return null;
  return TimeOfDay(hour: hh, minute: mm);
}

/// Para enseñar una hora: "5:30 PM".
String hora12(TimeOfDay h) => formatoHora12(horaATexto(h));

String horaATexto(TimeOfDay h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

/// Días de clase y la hora de cada uno: un día puede empezar a otra hora que
/// el resto. Modifica [dias] y [horas] y avisa con [onCambio] para repintar.
class EditorHorarioSemanal extends StatelessWidget {
  const EditorHorarioSemanal({
    super.key,
    required this.dias,
    required this.horas,
    required this.onCambio,
  });

  final Set<int> dias;
  final Map<int, TimeOfDay> horas;
  final VoidCallback onCambio;

  static const _nombres = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final ordenados = dias.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(Grupo.nombresDias[d - 1]),
                selected: dias.contains(d),
                onSelected: (v) {
                  if (v) {
                    dias.add(d);
                    // Un día nuevo empieza a la misma hora que los demás; se
                    // cambia después si hace falta.
                    final otra = horas.values.firstOrNull;
                    if (otra != null) horas[d] = otra;
                  } else {
                    dias.remove(d);
                    horas.remove(d);
                  }
                  onCambio();
                },
              ),
          ],
        ),
        for (final d in ordenados)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(_nombres[d - 1],
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final h = await elegirHoraDigital(context, horas[d]);
                      if (h != null) {
                        horas[d] = h;
                        onCambio();
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                        horas[d] == null ? 'Elegir hora' : hora12(horas[d]!)),
                  ),
                ),
              ],
            ),
          ),
        if (ordenados.length > 1 && horas[ordenados.first] != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final h = horas[ordenados.first]!;
                for (final d in ordenados) {
                  horas[d] = h;
                }
                onCambio();
              },
              child: Text(
                  'Misma hora todos los días (${hora12(horas[ordenados.first]!)})'),
            ),
          ),
      ],
    );
  }
}

/// Horas de la ficha como mapa `día → HH:mm`, solo de los días que hay.
Map<int, String> horasATextos(Set<int> dias, Map<int, TimeOfDay> horas) => {
      for (final d in (dias.toList()..sort()))
        if (horas[d] != null) d: horaATexto(horas[d]!),
    };

/// `HH:mm` del primer día, o vacío: se guarda también como `horaInicio` para
/// lo que lea la ficha sin conocer las horas por día.
String horaPrincipal(Set<int> dias, Map<int, TimeOfDay> horas) {
  final d = (dias.toList()..sort()).where((d) => horas[d] != null).firstOrNull;
  return d == null ? '' : horaATexto(horas[d]!);
}

/// Horas iniciales del editor para una ficha.
Map<int, TimeOfDay> horasDe(Alumna a, {String? porDefecto}) => {
      for (final d in a.dias)
        if (horaDeTexto(a.horaDelDia(d).isEmpty ? porDefecto : a.horaDelDia(d))
            case final h?)
          d: h,
    };

/// Cambia el horario FIJO (todas las semanas desde ahora).
Future<void> _horarioFijo(BuildContext context, Alumna alumna) async {
  final repo = context.read<ClubRepository>();
  final raiz = context;
  final dias = <int>{...alumna.dias};
  final horas = horasDe(alumna);
  var duracion = alumna.duracionMinutos;

  final guardar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Horario de ${alumna.nombreCorto}',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Elige los días y la hora de cada uno.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              EditorHorarioSemanal(
                dias: dias,
                horas: horas,
                onCambio: () => setSheet(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: duracion,
                decoration: const InputDecoration(labelText: 'Duración'),
                items: const [
                  DropdownMenuItem(value: 45, child: Text('45 min')),
                  DropdownMenuItem(value: 60, child: Text('1 h')),
                  DropdownMenuItem(value: 90, child: Text('1 h 30')),
                  DropdownMenuItem(value: 120, child: Text('2 h')),
                ],
                onChanged: (v) => setSheet(() => duracion = v ?? 60),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar horario'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (guardar != true) return;
  try {
    await repo.actualizarAlumna(
      alumna.id,
      dias: dias.toList()..sort(),
      horaInicio: horaPrincipal(dias, horas),
      horarios: horasATextos(dias, horas),
      duracionMinutos: duracion,
    );
    if (raiz.mounted) {
      showAppSnackBar(raiz, 'Horario de ${alumna.nombreCorto} actualizado.');
    }
  } catch (_) {
    if (raiz.mounted) {
      showAppSnackBar(raiz, 'No se pudo guardar el horario.', isError: true);
    }
  }
}

/// Punto de entrada: qué quieres cambiar de la clase de esta persona.
Future<void> editarHorario(BuildContext context, Alumna alumna) async {
  final repo = context.read<ClubRepository>();
  final eleccion = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Clase de ${alumna.nombreCorto}',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Ahora: ${alumna.horarioTexto}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.event_repeat, color: AppColors.navy),
                  title: const Text('Cambiar un día concreto'),
                  subtitle: const Text(
                      'Solo ese día, o varias semanas. El horario fijo no se toca.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, 'puntual'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.edit_calendar, color: AppColors.navy),
                  title: const Text('Cambiar el horario fijo'),
                  subtitle:
                      const Text('Para todas las semanas a partir de hoy.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, 'fijo'),
                ),
              ),
              StreamBuilderEstable<List<CambioClase>>(
                streamKey: alumna.id,
                stream: repo.watchCambiosAlumna(alumna),
                builder: (context, snap) {
                  final hoy = claveFecha(DateTime.now());
                  final proximos = (snap.data ?? const <CambioClase>[])
                      .where((c) => c.fecha.compareTo(hoy) >= 0)
                      .toList();
                  if (proximos.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader('Cambios programados'),
                      CardList(
                        children: [
                          for (final c in proximos)
                            ListTile(
                              dense: true,
                              title: Text(textoCambioClase(c)),
                              trailing: IconButton(
                                tooltip: 'Quitar este cambio',
                                icon: const Icon(Icons.close,
                                    color: AppColors.danger),
                                onPressed: () => repo.eliminarCambio(c.id),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || eleccion == null) return;
  if (eleccion == 'fijo') {
    await _horarioFijo(context, alumna);
  } else {
    await _cambioPuntual(context, alumna);
  }
}

String textoCambioClase(CambioClase c) {
  final dia = capitalizar(fechaCortaFormat.format(fechaDeClave(c.fecha)));
  return c.tipo == TipoCambio.cancelada
      ? '$dia: no hay clase'
      : '$dia: clase${c.horaInicio.isEmpty ? '' : ' a las ${formatoHora12(c.horaInicio)}'}';
}

enum _Modo { noViene, otroDia, otraHora }

/// Cambio de un día concreto, repetible varias semanas.
Future<void> _cambioPuntual(BuildContext context, Alumna alumna) async {
  final repo = context.read<ClubRepository>();
  final porUid = context.read<SessionController>().appUser!.uid;
  final raiz = context;
  final hoy = DateTime.now();
  final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);

  // Por defecto, la próxima clase que le toca.
  var origen = hoyDia;
  for (var i = 0; i < 14; i++) {
    final d = hoyDia.add(Duration(days: i));
    if (alumna.tieneClaseEl(d)) {
      origen = d;
      break;
    }
  }
  var nuevo = origen.add(const Duration(days: 1));
  var hora = horaDeTexto(alumna.horaDelDia(origen.weekday));
  var modo = _Modo.noViene;
  var semanas = 1; // 0 = hasta fin de mes

  String dia(DateTime d) => capitalizar(fechaLargaFormat.format(d));

  Future<DateTime?> elegirDia(BuildContext context, DateTime inicial) =>
      showDatePicker(
        context: context,
        initialDate: inicial,
        firstDate: hoyDia.subtract(const Duration(days: 1)),
        lastDate: hoyDia.add(const Duration(days: 365)),
      );

  final guardar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cambio de clase de ${alumna.nombreCorto}',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Su horario fijo no se modifica.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text('Día que cambia: ${dia(origen)}'),
                onPressed: () async {
                  final f = await elegirDia(context, origen);
                  if (f != null) setSheet(() => origen = f);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<_Modo>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Modo.noViene, label: Text('No viene')),
                  ButtonSegment(value: _Modo.otroDia, label: Text('Otro día')),
                  ButtonSegment(
                      value: _Modo.otraHora, label: Text('Otra hora')),
                ],
                selected: {modo},
                onSelectionChanged: (s) => setSheet(() => modo = s.first),
              ),
              if (modo == _Modo.otroDia) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: Text('Viene el: ${dia(nuevo)}'),
                  onPressed: () async {
                    final f = await elegirDia(context, nuevo);
                    if (f != null) setSheet(() => nuevo = f);
                  },
                ),
              ],
              if (modo != _Modo.noViene) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(hora == null ? 'Hora' : hora12(hora!)),
                  onPressed: () async {
                    final h = await elegirHoraDigital(context, hora);
                    if (h != null) setSheet(() => hora = h);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: semanas,
                decoration: const InputDecoration(labelText: 'Se aplica'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Solo ese día')),
                  DropdownMenuItem(
                      value: 2, child: Text('Ese día y la semana siguiente')),
                  DropdownMenuItem(value: 3, child: Text('Durante 3 semanas')),
                  DropdownMenuItem(value: 4, child: Text('Durante 4 semanas')),
                  DropdownMenuItem(
                      value: 0,
                      child: Text('Todas las semanas hasta fin de mes')),
                ],
                onChanged: (v) => setSheet(() => semanas = v ?? 1),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar cambio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (guardar != true) return;

  final horaTexto = hora == null ? '' : horaATexto(hora!);
  final cambios = <({String fecha, TipoCambio tipo, String hora})>[];
  var k = 0;
  while (true) {
    final o = origen.add(Duration(days: 7 * k));
    if (semanas == 0 ? o.month != origen.month : k >= semanas) break;
    switch (modo) {
      case _Modo.noViene:
        cambios
            .add((fecha: claveFecha(o), tipo: TipoCambio.cancelada, hora: ''));
      case _Modo.otroDia:
        final n = nuevo.add(Duration(days: 7 * k));
        if (claveFecha(n) != claveFecha(o)) {
          cambios.add(
              (fecha: claveFecha(o), tipo: TipoCambio.cancelada, hora: ''));
        }
        cambios.add(
            (fecha: claveFecha(n), tipo: TipoCambio.extra, hora: horaTexto));
      case _Modo.otraHora:
        cambios.add(
            (fecha: claveFecha(o), tipo: TipoCambio.extra, hora: horaTexto));
    }
    k++;
    if (k > 12) break;
  }
  try {
    await repo.guardarCambios(alumna: alumna, cambios: cambios, porUid: porUid);
    if (raiz.mounted) {
      showAppSnackBar(
        raiz,
        'Cambio guardado. ${alumna.vinculada ? 'Se avisa a la familia.' : ''}',
      );
    }
  } catch (_) {
    if (raiz.mounted) {
      showAppSnackBar(raiz, 'No se pudo guardar el cambio.', isError: true);
    }
  }
}
