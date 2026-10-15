import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/club_config.dart';
import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/pago_widgets.dart';
import '../app_shell.dart';

/// Pagos de la familia: a dónde transferir, qué debe, qué ha pagado, y subir
/// el justificante.
class PagosFamiliaScreen extends StatelessWidget {
  const PagosFamiliaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();
    return Scaffold(
      appBar: const TabAppBar(title: 'Pagos'),
      body: StreamView<List<Pago>>(
        stream: repo.watchPagosFamilia(user.uid),
        builder: (context, pagos) {
          final ahora = DateTime.now();
          final porPagar = pagos.where((p) => p.necesitaAccionFamilia).toList();
          final pagadas =
              pagos.where((p) => p.estado == EstadoPago.pagado).toList();

          String totales(List<Pago> lista) {
            if (lista.isEmpty) return formatoImporte(0, ClubConfig.monedaPorDefecto);
            final porMoneda = <Moneda, double>{};
            for (final p in lista) {
              porMoneda[p.moneda] = (porMoneda[p.moneda] ?? 0) + p.importe;
            }
            return porMoneda.entries
                .map((e) => formatoImporte(e.value, e.key))
                .join(' + ');
          }

          return PageBody(
            children: [
              KpiGrid(children: [
                KpiTile(
                  valor: totales(porPagar),
                  etiqueta: porPagar.isEmpty
                      ? 'Nada pendiente'
                      : 'Pendiente (${porPagar.length})',
                  color: porPagar.any((p) => p.vencidaEn(ahora))
                      ? AppColors.danger
                      : porPagar.isEmpty
                          ? AppColors.success
                          : AppColors.warning,
                  icon: Icons.pending_actions_outlined,
                ),
                KpiTile(
                  valor: '${pagadas.length}',
                  etiqueta: pagadas.length == 1
                      ? 'Cuota pagada'
                      : 'Cuotas pagadas',
                  color: AppColors.success,
                  icon: Icons.verified_outlined,
                ),
              ]),
              const SectionHeader(
                'Dónde transferir',
                subtitle: 'Haz la transferencia desde tu banco y sube aquí '
                    'el justificante de la cuota.',
              ),
              StreamView<AjustesClub>(
                stream: repo.watchAjustes(),
                builder: (context, ajustes) {
                  if (!ajustes.tieneCuentas) {
                    return const InlineNotice(
                      message: 'El club aún no ha publicado sus datos '
                          'bancarios. Consulta con Dirección.',
                      icon: Icons.info_outline,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in ajustes.cuentas) ...[
                        CuentaBancariaCard(c),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (ajustes.instrucciones.isNotEmpty)
                        InlineNotice(
                          message: ajustes.instrucciones,
                          icon: Icons.lightbulb_outline,
                        ),
                    ],
                  );
                },
              ),
              const SectionHeader('Mis cuotas'),
              if (pagos.isEmpty)
                const EmptyState(
                  compacto: true,
                  icon: Icons.receipt_long_outlined,
                  title: 'Aún no hay cuotas',
                  message: 'Aparecerán aquí cuando el club genere las del mes.',
                )
              else
                CardList(
                  children: [for (final p in pagos) _FilaCuota(pago: p)],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilaCuota extends StatefulWidget {
  const _FilaCuota({required this.pago});
  final Pago pago;

  @override
  State<_FilaCuota> createState() => _FilaCuotaState();
}

class _FilaCuotaState extends State<_FilaCuota> {
  bool _subiendo = false;

  Future<void> _subir() async {
    final user = context.read<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();

    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
      withData: true,
    );
    final archivo = r?.files.single;
    if (archivo == null || archivo.bytes == null) return;

    if (archivo.size > 8 * 1024 * 1024) {
      if (mounted) {
        showAppSnackBar(
          context,
          'El archivo pesa más de 8 MB. Haz una captura de pantalla del '
          'justificante y súbela.',
          isError: true,
        );
      }
      return;
    }
    final ext = (archivo.extension ?? '').toLowerCase();
    final tipo = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    setState(() => _subiendo = true);
    try {
      await repo.subirComprobante(
        pago: widget.pago,
        uid: user.uid,
        bytes: archivo.bytes!,
        nombreArchivo: archivo.name,
        contentType: tipo,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          'Justificante enviado. Te avisaremos cuando el club lo valide.',
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo subir el justificante. Inténtalo de nuevo.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pago;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.alumnaNombre.split(' ').first} · ${p.periodoLabel}',
                      style: t.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        formatoImporte(p.importe, p.moneda),
                        if (p.fechaLimite != null &&
                            p.necesitaAccionFamilia)
                          'vence ${fechaFormat.format(p.fechaLimite!)}',
                        if (p.estado == EstadoPago.pagado &&
                            p.resueltoEn != null)
                          'validada ${fechaFormat.format(p.resueltoEn!)}',
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              EstadoPagoChip(p),
            ],
          ),
          if (p.estado == EstadoPago.rechazado &&
              (p.motivoRechazo ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineNotice(
              message: 'Motivo del club: ${p.motivoRechazo}',
              icon: Icons.report_outlined,
              color: AppColors.danger,
            ),
          ],
          if (p.necesitaAccionFamilia) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _subiendo ? null : _subir,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: _subiendo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file, size: 19),
              label: Text(_subiendo
                  ? 'Subiendo…'
                  : p.estado == EstadoPago.rechazado
                      ? 'Subir otro justificante'
                      : 'Adjuntar justificante'),
            ),
          ] else if (p.tieneComprobante) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => abrirComprobante(context, p),
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Ver justificante'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
