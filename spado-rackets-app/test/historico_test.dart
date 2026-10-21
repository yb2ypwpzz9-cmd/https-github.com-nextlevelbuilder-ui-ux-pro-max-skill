import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spado_rackets_app/models/alumna.dart';
import 'package:spado_rackets_app/services/excel_export.dart';
import 'package:spado_rackets_app/services/excel_import.dart';
import 'package:spado_rackets_app/services/historico.dart';

Alumna alumna(String id, String nombre, {double cuota = 80}) => Alumna(
      id: id,
      nombre: nombre,
      grupo: 'general',
      activa: true,
      cuotaMensual: cuota,
    );

void main() {
  final hoy = DateTime(2026, 10, 20);
  final lucia = alumna('a1', 'Lucía Pérez');
  final sofia = alumna('a2', 'Sofía Gómez', cuota: 60);
  final todas = [lucia, sofia];

  test('la plantilla se lee de vuelta sin errores', () {
    final plantilla = plantillaHistorico(
        todas, mesesEntre(DateTime(2026, 5), DateTime(2026, 9)));
    final hojas = leerXlsx(construirXlsx(plantilla));
    expect(hojas.keys, containsAll(['Instrucciones', 'Cuotas', 'Gastos']));
    final l = leerHistorico(hojas, todas, hoy: hoy);
    expect(l.errores, isEmpty);
    expect(l.cuotas.length, 10); // 2 personas × 5 meses
    expect(l.cuotas.first.importe, isNotNull);
    expect(l.cuotas.where((c) => c.alumna.id == 'a2').first.importe, 60);
  });

  test('filas con problemas: salen como error y el resto pasa', () {
    final hojas = {
      'Cuotas': [
        ['ID', 'Nombre', 'Mes', 'Importe', 'Forma', 'Fecha'],
        ['a1', 'Lucía', '2026-05', '80', 'Efectivo', '03/05/2026'],
        ['', 'sofia gomez', '06/2026', '60,5', '', ''],
        ['', 'Nadie', '2026-05', '80', '', ''],
        ['a1', '', '2026-13', '80', '', ''],
        ['a1', '', '2026-11', '80', '', ''], // futuro
        ['a1', '', '2026-05', '80', '', ''], // repetida
        ['a2', '', '2026-07', '', '', ''], // sin importe
        ['a2', '', '2026-08', '-4', '', ''],
        ['a2', '', '2026-08', '50', 'bizum', ''],
      ],
      'Gastos': [
        ['Fecha', 'Concepto', 'Categoría', 'Importe'],
        ['15/05/2026', 'Alquiler pistas', 'Pistas y alquiler', '1,250.50'],
        ['46150', 'Pelotas', 'material', '40'], // número de serie de Excel
        ['31/02/2026', 'X', 'otros', '5'],
        ['01/06/2026', 'Y', 'inventada', '5'],
      ],
    };
    final l = leerHistorico(hojas, todas, hoy: hoy);
    expect(l.cuotas.map((c) => '${c.alumna.id} ${c.periodo}'),
        ['a1 2026-05', 'a2 2026-06']);
    expect(l.cuotas[0].efectivo, isTrue);
    expect(l.cuotas[0].fechaPago, DateTime(2026, 5, 3));
    expect(l.cuotas[1].importe, 60.5);
    expect(l.sinImporte, 1);
    expect(l.errores.where((e) => e.hoja == 'Cuotas').length, 6);
    expect(l.gastos.length, 2);
    expect(l.gastos[0].importe, 1250.5);
    expect(l.gastos[0].fecha, '2026-05-15');
    expect(l.gastos[1].fecha, '2026-05-08');
    expect(l.errores.where((e) => e.hoja == 'Gastos').length, 2);
  });

  test('lee un libro guardado por Excel (textos compartidos y números)', () {
    const cab = '<?xml version="1.0" encoding="UTF-8"?>';
    const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    final zip = Archive();
    void add(String r, String c) {
      final b = utf8.encode(c);
      zip.addFile(ArchiveFile(r, b.length, b));
    }

    add('xl/workbook.xml',
        '$cab<workbook xmlns="$ns" xmlns:r="x"><sheets><sheet name="Cuotas" sheetId="1" r:id="rId1"/></sheets></workbook>');
    add('xl/_rels/workbook.xml.rels',
        '$cab<Relationships><Relationship Id="rId1" Type="t" Target="worksheets/sheet1.xml"/></Relationships>');
    add('xl/sharedStrings.xml',
        '$cab<sst xmlns="$ns"><si><t>Nombre</t></si><si><r><t>Luc</t></r><r><t>ía &amp; Co</t></r></si></sst>');
    add('xl/worksheets/sheet1.xml',
        '$cab<worksheet xmlns="$ns"><sheetData><row r="1"><c r="B1" t="s"><v>0</v></c></row>'
        '<row r="2"><c r="B2" t="s"><v>1</v></c><c r="D2"><v>80</v></c></row></sheetData></worksheet>');
    final hojas = leerXlsx(Uint8List.fromList(ZipEncoder().encode(zip)));
    expect(hojas['Cuotas']![0], ['', 'Nombre']);
    expect(hojas['Cuotas']![1], ['', 'Lucía & Co', '', '80']);
  });

  test('importes y fechas', () {
    expect(parsearImporte('US\$ 1,250.50'), 1250.5);
    expect(parsearImporte('1.250,50'), 1250.5);
    expect(parsearImporte('80,5'), 80.5);
    expect(parsearImporte('abc'), isNull);
    expect(parsearFecha('5/3/26'), DateTime(2026, 3, 5));
    expect(parsearFecha('2026-03-05'), DateTime(2026, 3, 5));
    expect(parsearMes('46143'), '2026-05');
  });
}
