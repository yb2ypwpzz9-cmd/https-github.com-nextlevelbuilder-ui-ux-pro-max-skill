import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/club_config.dart';
import '../../models/pago.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Cuentas del club que ven las familias en "Pagos".
class DatosBancariosScreen extends StatelessWidget {
  const DatosBancariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos bancarios')),
      body: StreamView<AjustesClub>(
        stream: context.read<ClubRepository>().watchAjustes(),
        builder: (context, ajustes) => _Formulario(inicial: ajustes),
      ),
    );
  }
}

class _CuentaEditable {
  _CuentaEditable(CuentaBancaria? c)
      : banco = TextEditingController(text: c?.banco),
        numero = TextEditingController(text: c?.numero),
        titular = TextEditingController(text: c?.titular),
        documento = TextEditingController(text: c?.documento),
        tipo = c?.tipo ?? 'Corriente',
        moneda = c?.moneda ?? ClubConfig.monedaPorDefecto;

  final TextEditingController banco;
  final TextEditingController numero;
  final TextEditingController titular;
  final TextEditingController documento;
  String tipo;
  Moneda moneda;

  CuentaBancaria get valor => CuentaBancaria(
        banco: banco.text.trim(),
        numero: numero.text.trim(),
        titular: titular.text.trim(),
        documento: documento.text.trim(),
        tipo: tipo,
        moneda: moneda,
      );

  void dispose() {
    banco.dispose();
    numero.dispose();
    titular.dispose();
    documento.dispose();
  }
}

class _Formulario extends StatefulWidget {
  const _Formulario({required this.inicial});
  final AjustesClub inicial;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  late final List<_CuentaEditable> _cuentas = widget.inicial.cuentas.isEmpty
      ? [_CuentaEditable(null)]
      : [for (final c in widget.inicial.cuentas) _CuentaEditable(c)];
  late final _instrucciones =
      TextEditingController(text: widget.inicial.instrucciones);
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _cuentas) {
      c.dispose();
    }
    _instrucciones.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final validas = _cuentas
        .map((c) => c.valor)
        .where((c) => c.banco.isNotEmpty && c.numero.isNotEmpty)
        .toList();
    setState(() => _guardando = true);
    try {
      await context.read<ClubRepository>().guardarAjustes(
            cuentas: validas,
            instrucciones: _instrucciones.text,
          );
      if (mounted) showAppSnackBar(context, 'Datos bancarios guardados.');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo guardar.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PageBody(
      children: [
        const InlineNotice(
          message: 'Las familias ven estas cuentas en su pestaña "Pagos", con '
              'botón para copiar el número. Las cuotas se cobran en US\$.',
        ),
        for (var i = 0; i < _cuentas.length; i++) ...[
          SectionHeader(
            'Cuenta ${i + 1}',
            action: _cuentas.length > 1
                ? TextButton(
                    onPressed: () =>
                        setState(() => _cuentas.removeAt(i).dispose()),
                    child: const Text('Quitar'),
                  )
                : null,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  TextField(
                    controller: _cuentas[i].banco,
                    decoration: const InputDecoration(
                      labelText: 'Banco',
                      hintText: 'Ej. Banco Popular, Banreservas, BHD',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _cuentas[i].numero,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Número de cuenta'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _cuentas[i].tipo,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                              value: 'Corriente',
                              child: Text('Corriente'),
                            ),
                            DropdownMenuItem(
                              value: 'Ahorros',
                              child: Text('Ahorros'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _cuentas[i].tipo = v ?? 'Corriente'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<Moneda>(
                          initialValue: _cuentas[i].moneda,
                          decoration:
                              const InputDecoration(labelText: 'Moneda'),
                          items: [
                            for (final m in Moneda.values)
                              DropdownMenuItem(
                                value: m,
                                child: Text(m.simbolo),
                              ),
                          ],
                          onChanged: (v) => setState(
                              () => _cuentas[i].moneda = v ?? Moneda.dop),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _cuentas[i].titular,
                    decoration: const InputDecoration(labelText: 'Titular'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _cuentas[i].documento,
                    decoration: const InputDecoration(
                      labelText: 'Documento del titular (pasaporte, cédula o RNC)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (_cuentas.length < 3)
          TextButton.icon(
            onPressed: () => setState(() => _cuentas.add(_CuentaEditable(null))),
            icon: const Icon(Icons.add),
            label: const Text('Añadir otra cuenta'),
          ),
        const SectionHeader('Instrucciones para las familias'),
        TextField(
          controller: _instrucciones,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Ej. En el concepto pon el nombre del alumno o alumna y el mes.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sólo Dirección puede cambiar estos datos.',
          style: t.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
