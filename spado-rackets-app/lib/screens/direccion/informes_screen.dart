import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/club_config.dart';
import '../../models/asistencia.dart';
import '../../models/gasto.dart';
import '../../models/grupo.dart';
import '../../models/jornada.dart';
import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Cuadro de mandos de Dirección: asistencia, fichajes, cobros y gastos de
/// los últimos meses, con descarga en CSV.
class InformesScreen extends StatefulWidget {
  const InformesScreen({super.key});

  @override
  State<InformesScreen> createState() => _InformesScreenState();
}

class _InformesScreenState extends State<InformesScreen> {
  int _meses = 3;

  late final ClubRepository _repo = context.read<ClubRepository>();
  late final Stream<List<Grupo>> _grupos = _repo.watchGrupos();
  late Stream<List<Jornada>> _jornadas;
  late Stream<List<Asistencia>> _asistencia;
  late Stream<List<Pago>> _pagos;
  late Stream<List<Gasto>> _gastos;

  @override
  void initState() {
    super.initState();
    _crearStreams();
  }

  DateTime get _desde {
    final h = DateTime.now();
    return DateTime(h.year, h.month - (_meses - 1));
  }

  void _crearStreams() {
    final d = _desde;
    _jornadas = _repo.watchJornadasDesde(d);
    _asistencia = _repo.watchAsistenciaDesde(claveFecha(d));
    _pagos = _repo.watchPagosDesde(periodoDe(d));
    _gastos = _repo.watchGastosDesde(claveFecha(d));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuadro de mandos')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => _nuevoGasto(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar gasto'),
      ),
      body: StreamView<List<Grupo>>(
        stream: _grupos,
        builder: (context, grupos) => StreamView<List<Jornada>>(
          stream: _jornadas,
          builder: (context, jornadas) => StreamView<List<Asistencia>>(
            stream: _asistencia,
            builder: (context, marcas) => StreamView<List<Pago>>(
              stream: _pagos,
              builder: (context, pagos) => StreamView<List<Gasto>>(
                stream: _gastos,
                builder: (context, gastos) => _Cuerpo(
                  meses: _meses,
                  desde: _desde,
                  onMeses: (v) => setState(() {
                    _meses = v;
                    _crearStreams();
                  }),
                  grupos: grupos,
                  jornadas: jornadas,
                  marcas: marcas,
                  pagos: pagos,
                  gastos: gastos,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _nuevoGasto(BuildContext context) async {
    final yo = context.read<SessionController>().appUser!;
    final concepto = TextEditingController();
    final importe = TextEditingController();
    var categoria = CategoriaGasto.pistas;
    var fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Registrar gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: concepto,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Concepto',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: importe,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importe',
                    prefixText: r'US$ ',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<CategoriaGasto>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final c in CategoriaGasto.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) => setLocal(() => categoria = v ?? categoria),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('dd/MM/yyyy').format(fecha)),
                  onPressed: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 31)),
                    );
                    if (f != null) setLocal(() => fecha = f);
                  },
                ),
              ],
            ),
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
      ),
    );
    if (ok != true || !context.mounted) return;
    final valor = double.tryParse(importe.text.trim().replaceAll(',', '.'));
    if (concepto.text.trim().isEmpty || valor == null || valor <= 0) {
      showAppSnackBar(context, 'Escribe un concepto y un importe válido.',
          isError: true);
      return;
    }
    try {
      await _repo.registrarGasto(
        concepto: concepto.text,
        categoria: categoria,
        importe: valor,
        fecha: claveFecha(fecha),
        porUid: yo.uid,
      );
      if (context.mounted) showAppSnackBar(context, 'Gasto registrado.');
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo guardar el gasto.', isError: true);
      }
    }
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.meses,
    required this.desde,
    required this.onMeses,
    required this.grupos,
    required this.jornadas,
    required this.marcas,
    required this.pagos,
    required this.gastos,
  });

  final int meses;
  final DateTime desde;
  final ValueChanged<int> onMeses;
  final List<Grupo> grupos;
  final List<Jornada> jornadas;
  final List<Asistencia> marcas;
  final List<Pago> pagos;
  final List<Gasto> gastos;

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dop = pagos;
    final cobrado = dop
        .where((p) => p.estado == EstadoPago.pagado)
        .fold<double>(0, (a, p) => a + p.importe);
    final emitido = dop.fold<double>(0, (a, p) => a + p.importe);
    final pendiente = emitido - cobrado;
    final totalGastos = gastos.fold<double>(0, (a, g) => a + g.importe);
    final balance = cobrado - totalGastos;
    final tasa = emitido == 0 ? null : (cobrado * 100 / emitido).round();

    // Serie mensual.
    final periodos = [
      for (var i = 0; i < meses; i++) periodoDe(DateTime(desde.year, desde.month + i)),
    ];
    double ingresosDe(String p) => dop
        .where((x) => x.periodo == p && x.estado == EstadoPago.pagado)
        .fold<double>(0, (a, x) => a + x.importe);
    double gastosDe(String p) =>
        gastos.where((g) => g.periodo == p).fold<double>(0, (a, g) => a + g.importe);

    // Fichajes por día de la semana.
    final fichajesDia = List<int>.filled(7, 0);
    for (final j in jornadas) {
      fichajesDia[j.entrada.weekday - 1]++;
    }

    // Asistencia por grupo y por día.
    final porGrupo = <Grupo, List<Asistencia>>{
      for (final g in grupos.where((g) => g.activo))
        g: marcas.where((m) => m.grupo == g.id).toList(),
    };
    final marcasDia = List.generate(7, (_) => <Asistencia>[]);
    for (final m in marcas) {
      try {
        marcasDia[fechaDeClave(m.fecha).weekday - 1].add(m);
      } catch (_) {}
    }

    // Staff: días fichados y hora media de llegada.
    final porStaff = <String, List<Jornada>>{};
    for (final j in jornadas) {
      porStaff.putIfAbsent(j.staffNombre, () => []).add(j);
    }

    return PageBody(
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('Este mes')),
            ButtonSegment(value: 3, label: Text('3 meses')),
            ButtonSegment(value: 6, label: Text('6 meses')),
            ButtonSegment(value: 12, label: Text('12 meses')),
          ],
          selected: {meses},
          onSelectionChanged: (s) => onMeses(s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        KpiGrid(children: [
          KpiTile(
            valor: formatoImporte(cobrado, ClubConfig.monedaPorDefecto),
            etiqueta: 'Cobrado',
            icon: Icons.payments_outlined,
            color: AppColors.success,
          ),
          KpiTile(
            valor: formatoImporte(pendiente, ClubConfig.monedaPorDefecto),
            etiqueta: 'Por cobrar${tasa == null ? '' : ' · cobrado $tasa%'}',
            icon: Icons.hourglass_bottom,
            color: pendiente > 0 ? AppColors.warning : AppColors.navy,
          ),
          KpiTile(
            valor: formatoImporte(totalGastos, ClubConfig.monedaPorDefecto),
            etiqueta: 'Gastos',
            icon: Icons.shopping_bag_outlined,
            color: AppColors.navy,
          ),
          KpiTile(
            valor: formatoImporte(balance, ClubConfig.monedaPorDefecto),
            etiqueta: 'Balance (cobrado − gastos)',
            icon: Icons.balance,
            color: balance >= 0 ? AppColors.success : AppColors.danger,
          ),
          KpiTile(
            valor: marcas.isEmpty ? '—' : '${porcentajeAsistencia(marcas)}%',
            etiqueta: 'Asistencia',
            icon: Icons.fact_check_outlined,
            color: AppColors.success,
          ),
          KpiTile(
            valor: '${jornadas.length}',
            etiqueta: 'Fichajes del staff',
            icon: Icons.badge_outlined,
          ),
        ]),

        const SectionHeader('Ingresos y gastos por mes',
            subtitle: 'Cobrado (azul) frente a gastos (naranja)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _BarrasMensuales(
              etiquetas: [
                for (final p in periodos)
                  DateFormat('MMM', 'es').format(DateTime(
                      int.parse(p.substring(0, 4)), int.parse(p.substring(5)))),
              ],
              a: [for (final p in periodos) ingresosDe(p)],
              b: [for (final p in periodos) gastosDe(p)],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CardList(children: [
          for (final p in periodos.reversed)
            ListTile(
              dense: true,
              title: Text(etiquetaPeriodo(p)),
              subtitle: Text(
                'Cobrado ${formatoImporte(ingresosDe(p), ClubConfig.monedaPorDefecto)} · '
                'Gastos ${formatoImporte(gastosDe(p), ClubConfig.monedaPorDefecto)}',
              ),
              trailing: Text(
                formatoImporte(ingresosDe(p) - gastosDe(p), ClubConfig.monedaPorDefecto),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ingresosDe(p) - gastosDe(p) >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ),
        ]),

        const SectionHeader('Asistencia por grupo'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(children: [
              for (final e in porGrupo.entries)
                _BarraH(
                  etiqueta: e.key.nombre,
                  fraccion: e.value.isEmpty
                      ? 0
                      : porcentajeAsistencia(e.value) / 100,
                  valor: e.value.isEmpty
                      ? 'Sin listas'
                      : '${porcentajeAsistencia(e.value)}%',
                  color: AppColors.success,
                ),
              if (porGrupo.isEmpty) Text('Aún no hay grupos', style: t.bodySmall),
            ]),
          ),
        ),

        const SectionHeader('Asistencia por día de la semana'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(children: [
              for (var i = 0; i < 7; i++)
                _BarraH(
                  etiqueta: _dias[i],
                  fraccion: marcasDia[i].isEmpty
                      ? 0
                      : porcentajeAsistencia(marcasDia[i]) / 100,
                  valor: marcasDia[i].isEmpty
                      ? '—'
                      : '${porcentajeAsistencia(marcasDia[i])}%',
                  color: AppColors.navySoft,
                ),
            ]),
          ),
        ),

        const SectionHeader('Fichajes por día de la semana',
            subtitle: 'Cuántas veces ha llegado el staff cada día'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(children: [
              for (var i = 0; i < 7; i++)
                _BarraH(
                  etiqueta: _dias[i],
                  fraccion: fichajesDia.reduce((a, b) => a > b ? a : b) == 0
                      ? 0
                      : fichajesDia[i] /
                          fichajesDia.reduce((a, b) => a > b ? a : b),
                  valor: '${fichajesDia[i]}',
                  color: AppColors.navy,
                ),
            ]),
          ),
        ),

        const SectionHeader('Staff'),
        CardList(children: [
          if (porStaff.isEmpty)
            const ListTile(title: Text('Sin fichajes en este periodo')),
          for (final e in porStaff.entries)
            ListTile(
              title: Text(e.key),
              subtitle: Text(
                '${e.value.length} días fichados · llegada media '
                '${_horaMedia(e.value)}'
                '${e.value.any((j) => !j.entradaConUbicacion) ? ' · alguno sin ubicación' : ''}',
              ),
            ),
        ]),

        const SectionHeader('Gastos registrados'),
        CardList(children: [
          if (gastos.isEmpty)
            const ListTile(
              title: Text('Todavía no hay gastos en este periodo'),
              subtitle: Text('Pulsa "Registrar gasto" para añadir el primero'),
            ),
          for (final g in gastos)
            ListTile(
              title: Text(g.concepto),
              subtitle: Text('${g.fecha} · ${g.categoria.label}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatoImporte(g.importe, ClubConfig.monedaPorDefecto),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.danger),
                    onPressed: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Eliminar gasto',
                        mensaje: '"${g.concepto}" dejará de contar en el '
                            'balance.',
                        accion: 'Eliminar',
                        peligrosa: true,
                      );
                      if (ok && context.mounted) {
                        await context.read<ClubRepository>().borrarGasto(g.id);
                      }
                    },
                  ),
                ],
              ),
            ),
        ]),

        const SectionHeader('Descargar informes',
            subtitle: 'CSV para Excel, con los datos del periodo elegido'),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          _Descarga('Asistencia', Icons.fact_check_outlined, () {
            _csv('asistencia', [
              ['Fecha', 'Grupo', 'Alumna', 'Estado', 'Marcado por'],
              for (final m in marcas)
                [
                  m.fecha,
                  grupos.where((g) => g.id == m.grupo).firstOrNull?.nombre ??
                      m.grupo,
                  m.alumnaNombre,
                  m.estado.label,
                  m.marcadoPorNombre,
                ],
            ]);
          }),
          _Descarga('Fichajes', Icons.badge_outlined, () {
            _csv('fichajes', [
              ['Fecha', 'Staff', 'Hora de llegada', 'Latitud', 'Longitud'],
              for (final j in jornadas)
                [
                  DateFormat('yyyy-MM-dd').format(j.entrada),
                  j.staffNombre,
                  DateFormat('HH:mm').format(j.entrada),
                  j.entradaLat,
                  j.entradaLng,
                ],
            ]);
          }),
          _Descarga('Cuotas', Icons.receipt_long_outlined, () {
            _csv('cuotas', [
              ['Periodo', 'Alumna', 'Grupo', 'Importe', 'Moneda', 'Estado'],
              for (final p in pagos)
                [
                  p.periodo,
                  p.alumnaNombre,
                  grupos.where((g) => g.id == p.grupo).firstOrNull?.nombre ??
                      p.grupo,
                  p.importe.toStringAsFixed(2),
                  p.moneda.wire,
                  p.estado.label,
                ],
            ]);
          }),
          _Descarga('Gastos', Icons.shopping_bag_outlined, () {
            _csv('gastos', [
              ['Fecha', 'Concepto', 'Categoría', 'Importe (US\$)'],
              for (final g in gastos)
                [g.fecha, g.concepto, g.categoria.label, g.importe.toStringAsFixed(2)],
            ]);
          }),
        ]),
        const SizedBox(height: AppSpacing.xl * 2),
      ],
    );
  }

  static String _horaMedia(List<Jornada> js) {
    if (js.isEmpty) return '—';
    final minutos = js
            .map((j) => j.entrada.hour * 60 + j.entrada.minute)
            .reduce((a, b) => a + b) ~/
        js.length;
    return '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutos % 60).toString().padLeft(2, '0')}';
  }

  static void _csv(String nombre, List<List<Object?>> filas) {
    descargarTexto(
      'spado-rackets-$nombre-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      filas.map(filaCsv).join('\r\n'),
    );
  }
}

class _Descarga extends StatelessWidget {
  const _Descarga(this.titulo, this.icono, this.onTap);
  final String titulo;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: onTap,
        icon: Icon(icono, size: 18),
        label: Text(titulo),
      );
}

/// Fila de barra horizontal: etiqueta, barra proporcional y valor.
class _BarraH extends StatelessWidget {
  const _BarraH({
    required this.etiqueta,
    required this.fraccion,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final double fraccion;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
          width: 86,
          child: Text(etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraccion.clamp(0, 1).toDouble(),
              minHeight: 14,
              backgroundColor: AppColors.border,
              color: color,
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// Barras agrupadas por mes: serie A (ingresos) y serie B (gastos).
class _BarrasMensuales extends StatelessWidget {
  const _BarrasMensuales({
    required this.etiquetas,
    required this.a,
    required this.b,
  });

  final List<String> etiquetas;
  final List<double> a;
  final List<double> b;

  @override
  Widget build(BuildContext context) {
    final maximo = [...a, ...b].fold<double>(0, (m, v) => v > m ? v : m);
    const alto = 130.0;
    double h(double v) => maximo == 0 ? 2 : (v / maximo * alto).clamp(2, alto);
    return SizedBox(
      height: alto + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < etiquetas.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 9,
                          height: h(a[i]),
                          decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 2),
                      Container(
                          width: 9,
                          height: h(b[i]),
                          decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(3))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(etiquetas[i], style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
