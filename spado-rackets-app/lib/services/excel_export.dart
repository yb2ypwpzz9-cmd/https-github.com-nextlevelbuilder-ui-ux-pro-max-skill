import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Libro de Excel (.xlsx) sencillo: varias hojas, primera fila en negrita con
/// fondo gris, anchos de columna ajustados y números como números.
///
/// Se escribe a mano (un .xlsx es un zip de XML) para no depender de otra
/// librería. Los textos van como texto, nunca como fórmula.
Uint8List construirXlsx(Map<String, List<List<Object?>>> hojas) {
  final nombres = hojas.keys.toList();
  final zip = Archive();

  void anadir(String ruta, String contenido) {
    final bytes = utf8.encode(contenido);
    zip.addFile(ArchiveFile(ruta, bytes.length, bytes));
  }

  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const cabecera = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

  anadir(
    '[Content_Types].xml',
    '$cabecera<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '${[for (var i = 0; i < nombres.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
    '</Types>',
  );
  anadir(
    '_rels/.rels',
    '$cabecera<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="$rel/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>',
  );
  anadir(
    'xl/workbook.xml',
    '$cabecera<workbook xmlns="$ns" xmlns:r="$rel"><sheets>'
    '${[for (var i = 0; i < nombres.length; i++) '<sheet name="${_esc(_nombreHoja(nombres[i]))}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
    '</sheets></workbook>',
  );
  anadir(
    'xl/_rels/workbook.xml.rels',
    '$cabecera<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${[for (var i = 0; i < nombres.length; i++) '<Relationship Id="rId${i + 1}" Type="$rel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
    '<Relationship Id="rId${nombres.length + 1}" Type="$rel/styles" Target="styles.xml"/>'
    '</Relationships>',
  );
  anadir(
    'xl/styles.xml',
    '$cabecera<styleSheet xmlns="$ns">'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFDDE3EA"/></patternFill></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>',
  );

  for (var i = 0; i < nombres.length; i++) {
    final filas = hojas[nombres[i]]!;
    final anchos = <int, int>{};
    final xmlFilas = StringBuffer();
    for (var r = 0; r < filas.length; r++) {
      xmlFilas.write('<row r="${r + 1}">');
      for (var c = 0; c < filas[r].length; c++) {
        final v = filas[r][c];
        final ref = '${_columna(c)}${r + 1}';
        final estilo = r == 0 ? ' s="1"' : '';
        final largo = '${v ?? ''}'.length;
        if (largo > (anchos[c] ?? 0)) anchos[c] = largo;
        if (v == null || '$v'.isEmpty) {
          if (r == 0) xmlFilas.write('<c r="$ref"$estilo/>');
        } else if (v is num && r > 0) {
          xmlFilas.write('<c r="$ref"><v>$v</v></c>');
        } else {
          xmlFilas.write(
              '<c r="$ref"$estilo t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
        }
      }
      xmlFilas.write('</row>');
    }
    final cols = anchos.entries
        .map((e) =>
            '<col min="${e.key + 1}" max="${e.key + 1}" width="${(e.value + 3).clamp(10, 55)}" customWidth="1"/>')
        .join();
    anadir(
      'xl/worksheets/sheet${i + 1}.xml',
      '$cabecera<worksheet xmlns="$ns">'
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
      '<cols>$cols</cols><sheetData>$xmlFilas</sheetData></worksheet>',
    );
  }

  final bytes = ZipEncoder().encode(zip);
  return Uint8List.fromList(bytes);
}

String _columna(int i) {
  var n = i;
  var s = '';
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return s;
}

String _nombreHoja(String n) {
  final limpio = n.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  return limpio.isEmpty
      ? 'Hoja'
      : (limpio.length > 31 ? limpio.substring(0, 31) : limpio);
}

final _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

String _esc(String s) => s
    .replaceAll(_controlChars, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
