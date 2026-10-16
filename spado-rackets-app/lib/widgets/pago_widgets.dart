import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

Color colorEstadoPago(Pago p, DateTime ahora) => switch (p.estado) {
      EstadoPago.pagado => AppColors.success,
      EstadoPago.enRevision => AppColors.info,
      EstadoPago.rechazado => AppColors.danger,
      EstadoPago.pendiente =>
        p.vencidaEn(ahora) ? AppColors.danger : AppColors.warning,
    };

String etiquetaEstadoPago(Pago p, DateTime ahora) =>
    p.estado == EstadoPago.pendiente && p.vencidaEn(ahora)
        ? 'Vencida'
        : p.estado.label;

class EstadoPagoChip extends StatelessWidget {
  const EstadoPagoChip(this.pago, {super.key});
  final Pago pago;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return StatusChip(
      label: etiquetaEstadoPago(pago, ahora),
      color: colorEstadoPago(pago, ahora),
    );
  }
}

/// Tarjeta con una cuenta del club y botón de copiar el número.
class CuentaBancariaCard extends StatelessWidget {
  const CuentaBancariaCard(this.cuenta, {super.key});
  final CuentaBancaria cuenta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget fila(String etiqueta, String valor, {bool copiable = false}) {
      if (valor.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(etiqueta, style: t.bodySmall)),
            Expanded(
              child: SelectableText(
                valor,
                style: copiable
                    ? t.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.6,
                      )
                    : t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (copiable)
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy, size: 19),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: valor));
                  if (context.mounted) showAppSnackBar(context, 'Copiado.');
                },
              ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(cuenta.banco, style: t.titleMedium)),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: StatusChip(
                    label: cuenta.moneda.simbolo,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            fila('Cuenta', cuenta.numero, copiable: true),
            fila('Tipo', cuenta.tipo),
            fila('Titular', cuenta.titular),
            fila('Documento', cuenta.documento, copiable: true),
          ],
        ),
      ),
    );
  }
}

/// Abre el justificante en una pestaña nueva. Se pide la URL en el momento:
/// sólo se obtiene si las reglas de Storage dejan leer el archivo.
Future<void> abrirComprobante(BuildContext context, Pago pago) async {
  final ruta = pago.comprobantePath;
  if (ruta == null) return;
  final repo = context.read<ClubRepository>();
  final String url;
  try {
    // Con la sesión de quien mira: las reglas de Storage deciden si puede.
    url = await repo.urlComprobante(ruta);
  } catch (e) {
    if (context.mounted) {
      final sinPermiso =
          '$e'.contains('unauthorized') || '$e'.contains('permission');
      showAppSnackBar(
        context,
        sinPermiso
            ? 'No tienes permiso para ver este justificante.'
            : 'No se pudo abrir el justificante.',
        isError: true,
      );
    }
    return;
  }
  if (!context.mounted) return;
  final nombre = pago.comprobanteNombre ?? 'Justificante';
  final esPdf = ruta.toLowerCase().endsWith('.pdf');
  // Se enseña dentro de la app. Abrir una pestaña nueva después de una espera
  // la bloquean muchos navegadores del móvil; aquí el botón "Abrir" sí es un
  // toque directo.
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(nombre,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (esPdf)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FilledButton.icon(
                onPressed: () =>
                    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Abrir PDF'),
              ),
            )
          else
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  loadingBuilder: (context, child, progreso) => progreso == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(Uri.parse(url),
                          webOnlyWindowName: '_blank'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir archivo'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
