import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pago.dart';
import '../services/auth_service.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class _Archivo {
  const _Archivo(this.nombre, this.bytes, this.tipo);
  final String nombre;
  final Uint8List bytes;
  final String tipo;
}

/// Pide un justificante (foto, captura o PDF) y lo devuelve ya leído, o `null`
/// si se cancela o es demasiado grande.
Future<_Archivo?> _elegirArchivo(BuildContext context) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
    withData: true,
  );
  final f = r?.files.single;
  if (f == null || f.bytes == null) return null;
  if (f.size > 8 * 1024 * 1024) {
    if (context.mounted) {
      showAppSnackBar(context, 'El archivo pesa más de 8 MB.', isError: true);
    }
    return null;
  }
  final nombre = f.name.toLowerCase();
  final tipo = nombre.endsWith('.pdf')
      ? 'application/pdf'
      : nombre.endsWith('.png')
          ? 'image/png'
          : nombre.endsWith('.webp')
              ? 'image/webp'
              : nombre.endsWith('.heic')
                  ? 'image/heic'
                  : 'image/jpeg';
  return _Archivo(f.name, f.bytes!, tipo);
}

/// Dirección registra un cobro: por transferencia (con la captura del banco que
/// llegó por WhatsApp, si la hay) o en efectivo, con la fecha real. Devuelve
/// `true` si se guardó.
Future<bool> registrarCobro(BuildContext context, Pago pago) async {
  final repo = context.read<ClubRepository>();
  final yo = context.read<SessionController>().appUser!;
  var efectivo = false;
  var fecha = DateTime.now();
  _Archivo? archivo;

  final ok = await showModalBottomSheet<bool>(
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
              Text('Registrar cobro', style: Theme.of(sheet).textTheme.titleLarge),
              Text(
                '${pago.alumnaNombre} · ${pago.periodoLabel} · '
                '${formatoImporte(pago.importe, pago.moneda)}',
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.account_balance_outlined),
                    label: Text('Transferencia'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Efectivo'),
                  ),
                ],
                selected: {efectivo},
                onSelectionChanged: (s) => setSheet(() {
                  efectivo = s.first;
                  if (efectivo) archivo = null;
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text('Fecha del pago: ${fechaFormat.format(fecha)}'),
                onPressed: () async {
                  final f = await showDatePicker(
                    context: sheet,
                    initialDate: fecha,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (f != null) setSheet(() => fecha = f);
                },
              ),
              if (!efectivo) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(archivo == null
                      ? 'Adjuntar justificante del banco (opcional)'
                      : archivo!.nombre),
                  onPressed: () async {
                    final a = await _elegirArchivo(sheet);
                    if (a != null) setSheet(() => archivo = a);
                  },
                ),
                if (archivo != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setSheet(() => archivo = null),
                      child: const Text('Quitar el archivo'),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
              const InlineNotice(
                message: 'La cuota pasa a "Pagada" y la familia recibe el aviso '
                    'de pago confirmado.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheet, true),
                icon: const Icon(Icons.check),
                label: const Text('Registrar cobro'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true) return false;
  try {
    await repo.registrarCobro(
      pago,
      quien: yo,
      efectivo: efectivo,
      fechaPago: fecha,
      bytes: archivo?.bytes,
      nombreArchivo: archivo?.nombre,
      contentType: archivo?.tipo,
    );
    if (context.mounted) {
      showAppSnackBar(
        context,
        efectivo ? 'Cobro en efectivo registrado.' : 'Cobro por transferencia registrado.',
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'No se pudo registrar el cobro. Revisa la conexión.',
          isError: true);
    }
    return false;
  }
}

/// Dirección guarda en una cuota el justificante que le llegó por WhatsApp,
/// sin cambiar su estado. Devuelve `true` si se guardó.
Future<bool> adjuntarJustificante(BuildContext context, Pago pago) async {
  final repo = context.read<ClubRepository>();
  final a = await _elegirArchivo(context);
  if (a == null) return false;
  try {
    await repo.adjuntarJustificante(
      pago,
      bytes: a.bytes,
      nombreArchivo: a.nombre,
      contentType: a.tipo,
    );
    if (context.mounted) showAppSnackBar(context, 'Justificante guardado.');
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'No se pudo guardar el justificante.',
          isError: true);
    }
    return false;
  }
}
