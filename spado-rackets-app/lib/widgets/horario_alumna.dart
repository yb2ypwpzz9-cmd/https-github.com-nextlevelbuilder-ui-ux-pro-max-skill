import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumna.dart';
import '../models/grupo.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Hora en formato digital (escribir "17" y "30"), más fácil en el móvil que
/// arrastrar las agujas de un reloj. Siempre en 24 horas.
Future<TimeOfDay?> elegirHoraDigital(
  BuildContext context,
  TimeOfDay? inicial,
) =>
    showTimePicker(
      context: context,
      initialTime: inicial ?? const TimeOfDay(hour: 17, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Hora de la clase (24 h)',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
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

String horaATexto(TimeOfDay h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

/// Cambio rápido de los días y la hora de clase de una persona. Lo puede hacer
/// el staff y Dirección.
Future<void> editarHorario(BuildContext context, Alumna alumna) async {
  final repo = context.read<ClubRepository>();
  final raiz = context;
  final dias = <int>{...alumna.dias};
  var hora = horaDeTexto(alumna.horaInicio);
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
              Text('Elige los días que viene a clase.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(Grupo.nombresDias[d - 1]),
                      selected: dias.contains(d),
                      onSelected: (v) =>
                          setSheet(() => v ? dias.add(d) : dias.remove(d)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final h = await elegirHoraDigital(context, hora);
                        if (h != null) setSheet(() => hora = h);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(hora == null ? 'Hora' : horaATexto(hora!)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<int>(
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
                  ),
                ],
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
      horaInicio: hora == null ? '' : horaATexto(hora!),
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
