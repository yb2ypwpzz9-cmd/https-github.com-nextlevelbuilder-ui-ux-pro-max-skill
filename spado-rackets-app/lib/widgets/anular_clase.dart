import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumna.dart';
import '../models/clase_anulada.dart';
import '../services/auth_service.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Anular la clase de un día a las personas que se elijan, por algo ajeno a
/// ellas (mal tiempo, pista, entrenador). No cuenta como falta, se avisa a las
/// familias y queda pendiente de recuperar.
Future<void> anularClase(
  BuildContext context, {
  required String fecha,
  required String fechaTexto,
  required List<Alumna> candidatos,
}) async {
  final repo = context.read<ClubRepository>();
  final yo = context.read<SessionController>().appUser!;
  final elegidas = <String>{for (final a in candidatos) a.id};
  int? minutos; // null = la clase entera de cada una
  var motivo = MotivoAnulacion.clima;
  final nota = TextEditingController();

  final guardar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, pieHoja(sheet)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Anular clase', style: Theme.of(sheet).textTheme.titleLarge),
              Text(fechaTexto, style: Theme.of(sheet).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader('¿A quién?'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Todas las personas'),
                    onPressed: () => setSheet(() => elegidas
                      ..clear()
                      ..addAll(candidatos.map((a) => a.id))),
                  ),
                  ActionChip(
                    label: const Text('Ninguna'),
                    onPressed: () => setSheet(elegidas.clear),
                  ),
                ],
              ),
              for (final a in candidatos)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: elegidas.contains(a.id),
                  onChanged: (v) => setSheet(
                      () => v == true ? elegidas.add(a.id) : elegidas.remove(a.id)),
                  title: Text(a.nombre),
                  subtitle: Text(a.horarioTexto),
                ),
              const SectionHeader('¿Cuánto no se pudo dar?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Clase entera'),
                    selected: minutos == null,
                    onSelected: (_) => setSheet(() => minutos = null),
                  ),
                  for (final m in const [30, 45, 60, 90])
                    ChoiceChip(
                      label: Text(duracionTexto(m)),
                      selected: minutos == m,
                      onSelected: (_) => setSheet(() => minutos = m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<MotivoAnulacion>(
                initialValue: motivo,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: [
                  for (final m in MotivoAnulacion.values)
                    DropdownMenuItem(value: m, child: Text(m.etiqueta)),
                ],
                onChanged: (v) => setSheet(() => motivo = v ?? motivo),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: nota,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const InlineNotice(
                message: 'No cuenta como falta. Las familias reciben un aviso '
                    'y el tiempo queda pendiente de recuperar.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: elegidas.isEmpty
                    ? null
                    : () => Navigator.pop(sheet, true),
                child: Text(elegidas.length == 1
                    ? 'Anular la clase de 1 persona'
                    : 'Anular la clase de ${elegidas.length} personas'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  final texto = nota.text;
  nota.dispose();
  if (guardar != true || elegidas.isEmpty) return;
  try {
    await repo.anularClases(
      fecha: fecha,
      alumnas: [for (final a in candidatos) if (elegidas.contains(a.id)) a],
      minutos: minutos,
      motivo: motivo,
      nota: texto,
      quien: yo,
    );
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Clase anulada. Se ha avisado a las familias y queda pendiente de '
        'recuperar.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'No se pudo anular la clase. Inténtalo de nuevo.',
          isError: true);
    }
  }
}
