import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/club_config.dart';
import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/pago_widgets.dart';
import '../app_shell.dart';

enum _Filtro { todas, revision, sinCobrar, pagadas }

/// Cuotas del mes: generarlas, revisar justificantes y registrar cobros.
class PagosDireccionScreen extends StatefulWidget {
  const PagosDireccionScreen({super.key});

  @override
  State<PagosDireccionScreen> createState() => _PagosDireccionScreenState();
}

class _PagosDireccionScreenState extends State<PagosDireccionScreen> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  _Filtro _filtro = _Filtro.todas;

  String get _periodo => periodoDe(_mes);

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubRepository>();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const TabAppBar(title: 'Pagos'),
      body: StreamView<List<Pago>>(
        streamKey: _periodo,
        stream: repo.watchPagosPeriodo(_periodo),
        builder: (context, pagos) {
          final ahora = DateTime.now();
          final cobrado = <Moneda, double>{};
          final total = <Moneda, double>{};
          for (final p in pagos) {
            total[p.moneda] = (total[p.moneda] ?? 0) + p.importe;
            if (p.estado == EstadoPago.pagado) {
              cobrado[p.moneda] = (cobrado[p.moneda] ?? 0) + p.importe;
            }
          }
          final filtrados = pagos.where((p) => switch (_filtro) {
                _Filtro.todas => true,
                _Filtro.revision => p.estado == EstadoPago.enRevision,
                _Filtro.sinCobrar => p.necesitaAccionFamilia,
                _Filtro.pagadas => p.estado == EstadoPago.pagado,
              }).toList()
            ..sort((a, b) {
              int peso(Pago p) => switch (p.estado) {
                    EstadoPago.enRevision => 0,
                    EstadoPago.rechazado => 1,
                    EstadoPago.pendiente => 2,
                    EstadoPago.pagado => 3,
                  };
              final c = peso(a).compareTo(peso(b));
              return c != 0 ? c : a.alumnaNombre.compareTo(b.alumnaNombre);
            });
          int cuenta(bool Function(Pago) f) => pagos.where(f).length;

          return PageBody(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() =>
                            _mes = DateTime(_mes.year, _mes.month - 1)),
                      ),
                      Expanded(
                        child: Text(
                          etiquetaPeriodo(_periodo),
                          textAlign: TextAlign.center,
                          style: t.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() =>
                            _mes = DateTime(_mes.year, _mes.month + 1)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              BotonExcel(
                onPressed: () => descargarExcel('cuotas-$_periodo', {
                  'Cuotas': [
                    ['Periodo', 'Nombre', 'Concepto', 'Importe', 'Moneda', 'Estado', 'Cobro', 'Validada por'],
                    for (final p in pagos)
                      [
                        p.periodo,
                        p.alumnaNombre,
                        p.concepto,
                        p.importe,
                        p.moneda.wire,
                        p.estado.label,
                        p.registradoAMano ? 'Efectivo' : (p.tieneComprobante ? 'Transferencia' : ''),
                        p.resueltoPorNombre,
                      ],
                  ],
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              if (pagos.isEmpty)
                EmptyState(
                  compacto: true,
                  icon: Icons.receipt_long_outlined,
                  title: 'Sin cuotas para este mes',
                  message: 'Genera las cuotas con el importe de cada ficha.',
                  action: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () =>
                        context.push('/cuotas/nueva?periodo=$_periodo'),
                    icon: const Icon(Icons.playlist_add),
                    label: Text('Generar cuotas de ${etiquetaPeriodo(_periodo)}'),
                  ),
                )
              else ...[
                KpiGrid(children: [
                  for (final m in total.keys)
                    KpiTile(
                      valor: formatoImporte(cobrado[m] ?? 0, m),
                      etiqueta: 'Cobrado de ${formatoImporte(total[m]!, m)}',
                      color: AppColors.success,
                      icon: Icons.payments_outlined,
                    ),
                  KpiTile(
                    valor:
                        '${cuenta((p) => p.estado == EstadoPago.pagado)}/${pagos.length}',
                    etiqueta: 'Cuotas pagadas',
                    icon: Icons.verified_outlined,
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (f, label) in [
                      (_Filtro.todas, 'Todas · ${pagos.length}'),
                      (
                        _Filtro.revision,
                        'En revisión · ${cuenta((p) => p.estado == EstadoPago.enRevision)}'
                      ),
                      (
                        _Filtro.sinCobrar,
                        'Sin cobrar · ${cuenta((p) => p.necesitaAccionFamilia)}'
                      ),
                      (
                        _Filtro.pagadas,
                        'Pagadas · ${cuenta((p) => p.estado == EstadoPago.pagado)}'
                      ),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _filtro == f,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (filtrados.isEmpty)
                  const EmptyState(
                    compacto: true,
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Ninguna cuota en este estado',
                  )
                else
                  CardList(
                    children: [
                      for (final p in filtrados)
                        ListTile(
                          title: Text(p.alumnaNombre),
                          subtitle: Text(
                            [
                              formatoImporte(p.importe, p.moneda),
                              if (p.tieneComprobante) 'con justificante',
                              if (p.registradoAMano) 'cobro manual',
                            ].join(' · '),
                          ),
                          trailing: EstadoPagoChip(p),
                          onTap: () => revisarPago(context, p),
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.push('/cuotas/nueva?periodo=$_periodo'),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Generar o añadir cuotas'),
                ),
                if (pagos.any((p) => p.vencidaEn(ahora))) ...[
                  const SizedBox(height: AppSpacing.md),
                  const InlineNotice(
                    message: 'Las cuotas sin pagar pasan a "Vencida" a partir '
                        'del día ${ClubConfig.diaVencimientoCuota + 1}.',
                    icon: Icons.info_outline,
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Hoja de revisión de una cuota: ver justificante y resolver.
Future<void> revisarPago(BuildContext context, Pago pago) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RevisarPago(pago: pago, raiz: context),
  );
}

class _RevisarPago extends StatefulWidget {
  const _RevisarPago({required this.pago, required this.raiz});
  final Pago pago;
  final BuildContext raiz;

  @override
  State<_RevisarPago> createState() => _RevisarPagoState();
}

class _RevisarPagoState extends State<_RevisarPago> {
  final _motivo = TextEditingController();
  bool _rechazando = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cambiarImporte() async {
    final repo = context.read<ClubRepository>();
    final controlador =
        TextEditingController(text: widget.pago.importe.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar importe'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '${widget.pago.moneda.simbolo} '),
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
    if (ok != true) return;
    final valor = double.tryParse(controlador.text.trim().replaceAll(',', '.'));
    if (valor == null || valor < 0) {
      if (mounted) showAppSnackBar(context, 'Importe no válido.', isError: true);
      return;
    }
    await _hacer(() => repo.actualizarImporteCuota(widget.pago, valor),
        'Importe actualizado.');
  }

  Future<void> _eliminar() async {
    final repo = context.read<ClubRepository>();
    final ok = await confirmar(
      context,
      titulo: 'Eliminar la cuota',
      mensaje: 'Se borra la cuota de ${widget.pago.alumnaNombre} '
          '(${widget.pago.periodoLabel}) y su justificante. No se puede '
          'deshacer.',
      accion: 'Eliminar',
      peligrosa: true,
    );
    if (!ok) return;
    await _hacer(() => repo.eliminarCuota(widget.pago), 'Cuota eliminada.');
  }

  Future<void> _hacer(Future<void> Function() accion, String ok) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.raiz.mounted) showAppSnackBar(widget.raiz, ok);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo guardar.', isError: true);
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pago;
    final repo = context.read<ClubRepository>();
    final yo = context.read<SessionController>().appUser!;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.alumnaNombre, style: t.titleLarge)),
              EstadoPagoChip(p),
            ],
          ),
          Text('${p.concepto} · ${p.periodoLabel}', style: t.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Importe'),
                  trailing: Text(
                    formatoImporte(p.importe, p.moneda),
                    style: t.titleMedium,
                  ),
                ),
                if (p.subidoEn != null)
                  ListTile(
                    title: const Text('Justificante subido'),
                    trailing: Text(fechaHoraFormat.format(p.subidoEn!)),
                  ),
                if (p.resueltoEn != null)
                  ListTile(
                    title: Text(p.estado == EstadoPago.pagado
                        ? 'Validada por'
                        : 'Resuelta por'),
                    trailing: Text(
                      '${p.resueltoPorNombre ?? '—'} · '
                      '${fechaFormat.format(p.resueltoEn!)}',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (p.tieneComprobante)
            OutlinedButton.icon(
              onPressed: () => abrirComprobante(context, p),
              icon: const Icon(Icons.open_in_new),
              label: Text('Abrir justificante (${p.comprobanteNombre ?? 'archivo'})'),
            )
          else
            const InlineNotice(
              message: 'La familia aún no ha subido justificante.',
            ),
          const SizedBox(height: AppSpacing.md),
          if (_rechazando) ...[
            TextField(
              controller: _motivo,
              autofocus: true,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Motivo (lo verá la familia)',
                hintText: 'Ej. el importe no coincide con la cuota',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _ocupado
                  ? null
                  : () {
                      if (_motivo.text.trim().isEmpty) {
                        showAppSnackBar(context, 'Escribe el motivo.',
                            isError: true);
                        return;
                      }
                      _hacer(
                        () => repo.resolverPago(p,
                            aprobado: false, quien: yo, motivo: _motivo.text),
                        'Justificante rechazado. La familia verá el motivo.',
                      );
                    },
              child: const Text('Confirmar rechazo'),
            ),
          ] else if (p.estado == EstadoPago.enRevision) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _ocupado
                  ? null
                  : () => _hacer(
                        () => repo.resolverPago(p, aprobado: true, quien: yo),
                        'Cuota marcada como pagada.',
                      ),
              icon: const Icon(Icons.check),
              label: const Text('Validar pago'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => setState(() => _rechazando = true),
              child: const Text('Rechazar justificante'),
            ),
          ] else if (p.necesitaAccionFamilia)
            OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _hacer(
                        () => repo.registrarCobroManual(p, yo),
                        'Cobro registrado.',
                      ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Registrar cobro en efectivo'),
            )
          else if (p.estado == EstadoPago.pagado)
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () => _hacer(
                        () => repo.reabrirPago(p),
                        'La cuota vuelve a estar pendiente.',
                      ),
              child: const Text('Deshacer: volver a pendiente'),
            ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _ocupado ? null : _cambiarImporte,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Cambiar importe'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _ocupado ? null : _eliminar,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar cuota'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
