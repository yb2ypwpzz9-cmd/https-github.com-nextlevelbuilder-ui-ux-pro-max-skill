import 'dart:typed_data';

import '../models/alumna.dart';
import '../models/gasto.dart';
import '../models/pago.dart';
import 'excel_import.dart';

/// Carga de histórico (cuotas cobradas y gastos de meses anteriores) desde un
/// Excel: la plantilla que se descarga y la lectura/validación de lo que se
/// sube. Aquí no se toca Firebase: solo se decide qué filas valen y cuáles no.

const hojaCuotas = 'Cuotas';
const hojaGastos = 'Gastos';

const _encabezadoCuotas = [
  'ID (no tocar)',
  'Nombre',
  'Mes (AAAA-MM)',
  'Importe US\$',
  'Forma de pago',
  'Fecha de pago (dd/mm/aaaa)',
];
const _encabezadoGastos = [
  'Fecha (dd/mm/aaaa)',
  'Concepto',
  'Categoría',
  'Importe US\$',
];

class CuotaHistorica {
  const CuotaHistorica({
    required this.fila,
    required this.alumna,
    required this.periodo,
    required this.importe,
    required this.efectivo,
    this.fechaPago,
  });

  final int fila;
  final Alumna alumna;
  final String periodo;
  final double importe;
  final bool efectivo;
  final DateTime? fechaPago;
}

class GastoHistorico {
  const GastoHistorico({
    required this.fila,
    required this.fecha,
    required this.concepto,
    required this.categoria,
    required this.importe,
  });

  final int fila;

  /// `yyyy-MM-dd`.
  final String fecha;
  final String concepto;
  final CategoriaGasto categoria;
  final double importe;
}

class ErrorFila {
  const ErrorFila(this.hoja, this.fila, this.mensaje);
  final String hoja;
  final int fila;
  final String mensaje;

  @override
  String toString() => '$hoja, fila $fila: $mensaje';
}

class LecturaHistorico {
  const LecturaHistorico({
    required this.cuotas,
    required this.gastos,
    required this.errores,
    required this.sinImporte,
  });

  final List<CuotaHistorica> cuotas;
  final List<GastoHistorico> gastos;
  final List<ErrorFila> errores;

  /// Filas de cuotas con el importe en blanco: se ignoran a propósito.
  final int sinImporte;
}

/// Meses `yyyy-MM` desde [desde] hasta [hasta], ambos incluidos.
List<String> mesesEntre(DateTime desde, DateTime hasta) {
  final out = <String>[];
  var m = DateTime(desde.year, desde.month);
  final fin = DateTime(hasta.year, hasta.month);
  while (!m.isAfter(fin)) {
    out.add(periodoDe(m));
    m = DateTime(m.year, m.month + 1);
  }
  return out;
}

/// Hojas de la plantilla: una fila de cuota por persona y mes, ya con el
/// importe de su ficha, para que solo haya que quitar o corregir.
Map<String, List<List<Object?>>> plantillaHistorico(
  List<Alumna> alumnas,
  List<String> periodos,
) {
  final ordenadas = [...alumnas]..sort((a, b) => a.nombre.compareTo(b.nombre));
  return {
    'Instrucciones': [
      ['Cómo rellenar este Excel'],
      ['1. Hoja "Cuotas": hay una fila por persona y mes con el importe de su ficha.'],
      ['   Borra las filas de los meses en que no fue alumno/a, y corrige el importe si pagó otra cantidad (por ejemplo, un mes con menos días).'],
      ['   Si dejas el importe en blanco, esa fila se ignora. No cambies la columna ID.'],
      ['   Forma de pago: Transferencia o Efectivo. La fecha de pago es opcional (dd/mm/aaaa).'],
      ['2. Hoja "Gastos": una fila por gasto, con fecha, concepto, categoría e importe.'],
      ['   Categorías: ${CategoriaGasto.values.map((c) => c.label).join(' · ')}.'],
      ['3. Todo en US\$. Guarda el archivo como .xlsx y súbelo en la app (Pagos → Cargar histórico).'],
      ['4. Antes de guardar nada, la app te enseña un resumen y las filas con error.'],
      ['5. Las cuotas que ya existen en la app no se tocan, y los gastos repetidos (misma fecha, concepto e importe) se saltan.'],
    ],
    hojaCuotas: [
      _encabezadoCuotas,
      for (final p in periodos)
        for (final a in ordenadas)
          [
            a.id,
            a.nombre,
            p,
            a.cuotaMensual > 0 ? a.cuotaMensual : null,
            'Transferencia',
            null,
          ],
    ],
    hojaGastos: [_encabezadoGastos],
  };
}

LecturaHistorico leerHistorico(
  Map<String, List<List<String>>> hojas,
  List<Alumna> alumnas, {
  DateTime? hoy,
}) {
  final ahora = hoy ?? DateTime.now();
  final errores = <ErrorFila>[];
  final cuotas = <CuotaHistorica>[];
  final gastos = <GastoHistorico>[];
  var sinImporte = 0;

  final porId = {for (final a in alumnas) a.id: a};
  final porNombre = <String, List<Alumna>>{};
  for (final a in alumnas) {
    porNombre.putIfAbsent(_norm(a.nombre), () => []).add(a);
  }

  final filasCuotas = hojas[hojaCuotas];
  final filasGastos = hojas[hojaGastos];
  if (filasCuotas == null && filasGastos == null) {
    errores.add(const ErrorFila('Archivo', 0,
        'No se encuentran las hojas "Cuotas" ni "Gastos". Usa la plantilla de la app.'));
  }

  String celda(List<String> f, int i) => i < f.length ? f[i].trim() : '';
  bool vacia(List<String> f) => f.every((c) => c.trim().isEmpty);

  if (filasCuotas != null) {
    final vistas = <String>{};
    for (var i = 1; i < filasCuotas.length; i++) {
      final f = filasCuotas[i];
      if (vacia(f)) continue;
      final n = i + 1;
      if (celda(f, 3).isEmpty) {
        sinImporte++;
        continue;
      }
      final id = celda(f, 0);
      Alumna? alumna = porId[id];
      if (alumna == null) {
        final candidatas = porNombre[_norm(celda(f, 1))] ?? const [];
        if (candidatas.length == 1) {
          alumna = candidatas.first;
        } else if (candidatas.length > 1) {
          errores.add(ErrorFila(hojaCuotas, n,
              'Hay varias personas llamadas "${celda(f, 1)}". Usa la columna ID.'));
          continue;
        }
      }
      if (alumna == null) {
        errores.add(ErrorFila(hojaCuotas, n,
            'No encuentro a "${celda(f, 1)}" en el alumnado.'));
        continue;
      }
      final periodo = parsearMes(celda(f, 2));
      if (periodo == null) {
        errores.add(ErrorFila(hojaCuotas, n,
            'El mes "${celda(f, 2)}" no es válido. Usa AAAA-MM, por ejemplo 2026-05.'));
        continue;
      }
      if (periodo.compareTo(periodoDe(ahora)) > 0) {
        errores.add(ErrorFila(hojaCuotas, n,
            'El mes $periodo es futuro: aquí solo se cargan meses ya cobrados.'));
        continue;
      }
      final importe = parsearImporte(celda(f, 3));
      if (importe == null || importe <= 0 || importe > 1000000) {
        errores.add(ErrorFila(hojaCuotas, n,
            'El importe "${celda(f, 3)}" no es válido.'));
        continue;
      }
      final forma = _norm(celda(f, 4));
      final bool efectivo;
      if (forma.isEmpty || forma.startsWith('transf')) {
        efectivo = false;
      } else if (forma.startsWith('efectivo')) {
        efectivo = true;
      } else {
        errores.add(ErrorFila(hojaCuotas, n,
            'La forma de pago "${celda(f, 4)}" no es válida: Transferencia o Efectivo.'));
        continue;
      }
      DateTime? fechaPago;
      if (celda(f, 5).isNotEmpty) {
        fechaPago = parsearFecha(celda(f, 5));
        if (fechaPago == null) {
          errores.add(ErrorFila(hojaCuotas, n,
              'La fecha de pago "${celda(f, 5)}" no es válida. Usa dd/mm/aaaa.'));
          continue;
        }
        if (fechaPago.isAfter(ahora)) {
          errores.add(ErrorFila(hojaCuotas, n, 'La fecha de pago es futura.'));
          continue;
        }
      }
      if (!vistas.add('${alumna.id}_$periodo')) {
        errores.add(ErrorFila(hojaCuotas, n,
            '${alumna.nombre} ya aparece en $periodo más arriba.'));
        continue;
      }
      cuotas.add(CuotaHistorica(
        fila: n,
        alumna: alumna,
        periodo: periodo,
        importe: importe,
        efectivo: efectivo,
        fechaPago: fechaPago,
      ));
    }
  }

  if (filasGastos != null) {
    for (var i = 1; i < filasGastos.length; i++) {
      final f = filasGastos[i];
      if (vacia(f)) continue;
      final n = i + 1;
      final fecha = parsearFecha(celda(f, 0));
      if (fecha == null) {
        errores.add(ErrorFila(hojaGastos, n,
            'La fecha "${celda(f, 0)}" no es válida. Usa dd/mm/aaaa.'));
        continue;
      }
      if (fecha.isAfter(ahora)) {
        errores.add(ErrorFila(hojaGastos, n, 'La fecha es futura.'));
        continue;
      }
      final concepto = celda(f, 1);
      if (concepto.isEmpty || concepto.length > 120) {
        errores.add(ErrorFila(hojaGastos, n,
            'El concepto es obligatorio (máximo 120 caracteres).'));
        continue;
      }
      final categoria = _categoria(celda(f, 2));
      if (categoria == null) {
        errores.add(ErrorFila(hojaGastos, n,
            'La categoría "${celda(f, 2)}" no existe. Usa: ${CategoriaGasto.values.map((c) => c.label).join(', ')}.'));
        continue;
      }
      final importe = parsearImporte(celda(f, 3));
      if (importe == null || importe <= 0 || importe > 100000000) {
        errores.add(ErrorFila(hojaGastos, n,
            'El importe "${celda(f, 3)}" no es válido.'));
        continue;
      }
      gastos.add(GastoHistorico(
        fila: n,
        fecha: _clave(fecha),
        concepto: concepto,
        categoria: categoria,
        importe: importe,
      ));
    }
  }

  return LecturaHistorico(
    cuotas: cuotas,
    gastos: gastos,
    errores: errores,
    sinImporte: sinImporte,
  );
}

/// Lee el .xlsx y lo valida.
LecturaHistorico leerHistoricoXlsx(
  Uint8List bytes,
  List<Alumna> alumnas, {
  DateTime? hoy,
}) =>
    leerHistorico(leerXlsx(bytes), alumnas, hoy: hoy);

// ------------------------------------------------------------ valores sueltos

/// `yyyy-MM`, `MM/yyyy`, `M-yyyy` o el número de serie de una fecha de Excel.
String? parsearMes(String texto) {
  final t = texto.trim();
  final serial = _serial(t);
  if (serial != null) return periodoDe(serial);
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})(?:[-/.]\d{1,2})?$').firstMatch(t);
  if (m != null) return _periodo(int.parse(m.group(1)!), int.parse(m.group(2)!));
  m = RegExp(r'^(\d{1,2})[-/.](\d{4})$').firstMatch(t);
  if (m != null) return _periodo(int.parse(m.group(2)!), int.parse(m.group(1)!));
  return null;
}

String? _periodo(int anio, int mes) {
  if (anio < 2020 || anio > 2100 || mes < 1 || mes > 12) return null;
  return '$anio-${mes.toString().padLeft(2, '0')}';
}

/// Día primero (como se escribe en República Dominicana): dd/mm/aaaa. También
/// acepta aaaa-mm-dd y el número de serie de Excel.
DateTime? parsearFecha(String texto) {
  final t = texto.trim();
  final serial = _serial(t);
  if (serial != null) return serial;
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
  int? d, mes, a;
  if (m != null) {
    a = int.parse(m.group(1)!);
    mes = int.parse(m.group(2)!);
    d = int.parse(m.group(3)!);
  } else {
    m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})$').firstMatch(t);
    if (m == null) return null;
    d = int.parse(m.group(1)!);
    mes = int.parse(m.group(2)!);
    a = int.parse(m.group(3)!);
    if (a < 100) a += 2000;
  }
  if (a < 2020 || a > 2100 || mes < 1 || mes > 12 || d < 1 || d > 31) {
    return null;
  }
  final f = DateTime(a, mes, d);
  return f.month == mes ? f : null; // rechaza 31/02
}

DateTime? _serial(String t) {
  final n = double.tryParse(t);
  if (n == null || n < 43831 || n > 73050) return null; // 2020 … 2099
  return DateTime(1899, 12, 30).add(Duration(days: n.floor()));
}

/// `80`, `80.5`, `US$ 1,250.50`, `1.250,50` o `80,5`.
double? parsearImporte(String texto) {
  var t = texto
      .toLowerCase()
      .replaceAll('us\$', '')
      .replaceAll('\$', '')
      .replaceAll('usd', '')
      .replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return null;
  final coma = t.lastIndexOf(',');
  final punto = t.lastIndexOf('.');
  if (coma >= 0 && punto >= 0) {
    t = coma > punto
        ? t.replaceAll('.', '').replaceAll(',', '.')
        : t.replaceAll(',', '');
  } else if (coma >= 0) {
    final decimales = t.length - coma - 1;
    t = decimales <= 2 ? t.replaceAll(',', '.') : t.replaceAll(',', '');
  }
  return double.tryParse(t);
}

CategoriaGasto? _categoria(String texto) {
  final t = _norm(texto);
  if (t.isEmpty) return CategoriaGasto.otros;
  for (final c in CategoriaGasto.values) {
    if (t == c.name || t == _norm(c.label)) return c;
  }
  for (final c in CategoriaGasto.values) {
    if (_norm(c.label).startsWith(t) || (t.length >= 4 && _norm(c.label).contains(t))) {
      return c;
    }
  }
  return null;
}

String _clave(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _norm(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final sb = StringBuffer();
  for (final r in s.toLowerCase().trim().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    sb.write(i >= 0 ? a[i] : c);
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ');
}
