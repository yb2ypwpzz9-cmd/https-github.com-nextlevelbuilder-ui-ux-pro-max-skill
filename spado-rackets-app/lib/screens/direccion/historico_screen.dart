import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../services/historico.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Carga de meses anteriores: se descarga una plantilla de Excel con una fila
/// por persona y mes, se corrige y se sube. Antes de guardar nada se enseña
/// un resumen con las filas que tienen error.
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  late final ClubRepository _repo = context.read<ClubRepository>();
  late final Stream<List<Alumna>> _alumnas = _repo.watchTodasLasAlumnas();

  late final List<DateTime> _opciones = () {
    final h = DateTime.now();
    return [
      for (var i = 1; i <= 24; i++) DateTime(h.year, h.month - i),
    ];
  }();
  late DateTime _desde = _opciones[(_opciones.length > 5 ? 5 : 0)]; // hace 6 meses
  bool _soloActivas = true;

  LecturaHistorico? _lectura;
  String? _archivo;
  Set<String> _yaExisten = {};
  bool _leyendo = false;
  bool _guardando = false;

  DateTime get _hasta {
    final h = DateTime.now();
    return DateTime(h.year, h.month - 1);
  }

  void _descargarPlantilla(List<Alumna> todas) {
    final lista = _soloActivas ? todas.where((a) => a.activa).toList() : todas;
    if (lista.isEmpty) {
      showAppSnackBar(context, 'No hay alumnado para la plantilla.',
          isError: true);
      return;
    }
    descargarExcel(
      'historico-plantilla',
      plantillaHistorico(lista, mesesEntre(_desde, _hasta)),
    );
  }

  Future<void> _subir(List<Alumna> todas) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    final f = r?.files.single;
    if (f?.bytes == null) return;
    if (f!.size > 8 * 1024 * 1024) {
      if (mounted) {
        showAppSnackBar(context, 'El archivo pesa demasiado.', isError: true);
      }
      return;
    }
    setState(() {
      _leyendo = true;
      _lectura = null;
    });
    try {
      final lectura = leerHistoricoXlsx(f.bytes!, todas);
      final ids = <String>{};
      for (final p in {for (final c in lectura.cuotas) c.periodo}) {
        ids.addAll(await _repo.idsDeCuotas(p));
      }
      if (!mounted) return;
      setState(() {
        _lectura = lectura;
        _archivo = f.name;
        _yaExisten = ids;
        _leyendo = false;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _leyendo = false);
      showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _leyendo = false);
      showAppSnackBar(context, 'No se pudo leer el archivo.', isError: true);
    }
  }

  Future<void> _importar() async {
    final l = _lectura!;
    final yo = context.read<SessionController>().appUser!;
    setState(() => _guardando = true);
    try {
      final r = await _repo.importarHistorico(
        cuotas: l.cuotas,
        gastos: l.gastos,
        quien: yo,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Cargadas ${r.cuotas} cuotas y ${r.gastos} gastos'
        '${r.cuotasYaExistian + r.gastosRepetidos > 0 ? ' (se saltaron ${r.cuotasYaExistian + r.gastosRepetidos} que ya estaban)' : ''}.',
      );
      setState(() {
        _lectura = null;
        _archivo = null;
        _guardando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      showAppSnackBar(
        context,
        'No se pudo guardar. No se ha cargado nada o solo una parte: '
        'vuelve a subir el mismo archivo, lo ya cargado se salta.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mes = DateFormat('MMMM yyyy', 'es');
    return Scaffold(
      appBar: AppBar(title: const Text('Cargar histórico')),
      body: StreamView<List<Alumna>>(
        stream: _alumnas,
        builder: (context, todas) => PageBody(
          children: [
            const InlineNotice(
              message: 'Para meses ya cobrados y gastos pasados. Las cuotas '
                  'entran como pagadas y no se avisa a las familias. Lo que '
                  'ya exista en la app no se pisa.',
            ),
            const SectionHeader('1. Descarga la plantilla'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<DateTime>(
                      initialValue: _desde,
                      decoration: const InputDecoration(
                          labelText: 'Cargar desde el mes de'),
                      items: [
                        for (final m in _opciones)
                          DropdownMenuItem(
                              value: m,
                              child: Text(capitalizar(mes.format(m)))),
                      ],
                      onChanged: (v) => setState(() => _desde = v ?? _desde),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo alumnado activo'),
                      value: _soloActivas,
                      onChanged: (v) => setState(() => _soloActivas = v),
                    ),
                    Text(
                      'Hasta ${capitalizar(mes.format(_hasta))}. La hoja trae '
                      'una fila por persona y mes con el importe de su ficha: '
                      'borra las que no toquen y corrige los importes.',
                      style: t.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: () => _descargarPlantilla(todas),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Descargar plantilla Excel'),
                    ),
                  ],
                ),
              ),
            ),
            const SectionHeader('2. Sube el Excel rellenado'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _leyendo || _guardando ? null : () => _subir(todas),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_leyendo ? 'Leyendo…' : 'Elegir archivo .xlsx'),
            ),
            if (_lectura != null) ..._resumen(context, _lectura!),
          ],
        ),
      ),
    );
  }

  List<Widget> _resumen(BuildContext context, LecturaHistorico l) {
    final t = Theme.of(context).textTheme;
    final nuevas = l.cuotas
        .where((c) => !_yaExisten.contains(Pago.idPara(c.alumna.id, c.periodo)))
        .toList();
    final repetidas = l.cuotas.length - nuevas.length;
    final total = nuevas.fold<double>(0, (s, c) => s + c.importe);
    final totalGastos = l.gastos.fold<double>(0, (s, g) => s + g.importe);
    final dinero = NumberFormat('#,##0.##', 'es');
    final hayErrores = l.errores.isNotEmpty;
    final nada = nuevas.isEmpty && l.gastos.isEmpty;

    return [
      const SectionHeader('3. Revisa y confirma'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_archivo ?? '', style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Text('${nuevas.length} cuotas nuevas · US\$ ${dinero.format(total)}',
                  style: t.titleSmall),
              if (repetidas > 0)
                Text('$repetidas ya existen en la app y se saltarán',
                    style: t.bodySmall),
              if (l.sinImporte > 0)
                Text('${l.sinImporte} filas sin importe, ignoradas',
                    style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Text('${l.gastos.length} gastos · US\$ ${dinero.format(totalGastos)}',
                  style: t.titleSmall),
              Text('Los gastos que ya estén (misma fecha, concepto e importe) se saltan.',
                  style: t.bodySmall),
            ],
          ),
        ),
      ),
      if (hayErrores) ...[
        const SizedBox(height: AppSpacing.md),
        InlineNotice(
          message: '${l.errores.length} filas con error. No se cargarán hasta '
              'que las corrijas; el resto sí puede cargarse.',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.sm),
        CardList(
          children: [
            for (final e in l.errores.take(40))
              ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 20),
                title: Text('${e.hoja} · fila ${e.fila}'),
                subtitle: Text(e.mensaje),
              ),
            if (l.errores.length > 40)
              ListTile(
                dense: true,
                title: Text('… y ${l.errores.length - 40} más'),
              ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: nada || _guardando ? null : _importar,
        icon: const Icon(Icons.check),
        label: Text(_guardando
            ? 'Guardando…'
            : hayErrores
                ? 'Cargar solo las filas correctas'
                : 'Cargar ${nuevas.length} cuotas y ${l.gastos.length} gastos'),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}
