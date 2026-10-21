import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Lee un .xlsx y devuelve, por hoja, sus filas como texto (las celdas vacías
/// quedan como cadena vacía). Entiende los archivos que genera
/// `construirXlsx` y los que guarda Excel (textos compartidos, números,
/// fechas como número de serie). Las fórmulas se leen por su último valor.
///
/// Lanza [FormatException] si el archivo no es un .xlsx.
Map<String, List<List<String>>> leerXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('No es un archivo de Excel (.xlsx).');
  }

  String? texto(String ruta) {
    final f = zip.findFile(ruta);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final libro = texto('xl/workbook.xml');
  if (libro == null) {
    throw const FormatException('No es un archivo de Excel (.xlsx).');
  }
  final rels = texto('xl/_rels/workbook.xml.rels') ?? '';

  final destinos = <String, String>{};
  for (final m in RegExp(r'<Relationship\b[^>]*>').allMatches(rels)) {
    final t = m.group(0)!;
    final id = _atributo(t, 'Id');
    final destino = _atributo(t, 'Target');
    if (id != null && destino != null) {
      destinos[id] = destino.startsWith('/')
          ? destino.substring(1)
          : 'xl/${destino.replaceFirst(RegExp(r'^\./'), '')}';
    }
  }

  final compartidos = <String>[];
  final xmlCompartidos = texto('xl/sharedStrings.xml');
  if (xmlCompartidos != null) {
    for (final si in RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true)
        .allMatches(xmlCompartidos)) {
      compartidos.add(_textosDe(si.group(1)!));
    }
  }

  final hojas = <String, List<List<String>>>{};
  for (final m in RegExp(r'<sheet\b[^>]*>').allMatches(libro)) {
    final t = m.group(0)!;
    final nombre = _desescapar(_atributo(t, 'name') ?? '');
    final id = _atributo(t, 'r:id');
    final ruta = id == null ? null : destinos[id];
    final xml = ruta == null ? null : texto(ruta);
    if (xml == null || nombre.isEmpty) continue;
    hojas[nombre] = _filas(xml, compartidos);
  }
  return hojas;
}

List<List<String>> _filas(String xml, List<String> compartidos) {
  final filas = <List<String>>[];
  for (final fila
      in RegExp(r'<row\b[^>]*?(?:/>|>(.*?)</row>)', dotAll: true)
          .allMatches(xml)) {
    final contenido = fila.group(1);
    final celdas = <String>[];
    if (contenido != null) {
      for (final c in RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true)
          .allMatches(contenido)) {
        final attrs = c.group(1)!;
        final cuerpo = c.group(2) ?? '';
        final ref = _atributo(attrs, 'r') ?? '';
        final col = _indiceColumna(ref);
        while (celdas.length < col) {
          celdas.add('');
        }
        final tipo = _atributo(attrs, 't');
        final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(cuerpo)?.group(1);
        String valor;
        if (tipo == 'inlineStr') {
          valor = _textosDe(cuerpo);
        } else if (tipo == 's') {
          final i = int.tryParse(v ?? '');
          valor = i != null && i >= 0 && i < compartidos.length
              ? compartidos[i]
              : '';
        } else {
          valor = _desescapar(v ?? '');
        }
        if (col < celdas.length) {
          celdas[col] = valor;
        } else {
          celdas.add(valor);
        }
      }
    }
    filas.add(celdas);
  }
  return filas;
}

int _indiceColumna(String ref) {
  final letras = RegExp(r'^[A-Z]+').firstMatch(ref.toUpperCase())?.group(0);
  if (letras == null) return 0;
  var n = 0;
  for (final u in letras.codeUnits) {
    n = n * 26 + (u - 64);
  }
  return n - 1;
}

String? _atributo(String etiqueta, String nombre) {
  final m = RegExp('(?:^|\\s)${RegExp.escape(nombre)}="([^"]*)"')
      .firstMatch(etiqueta);
  return m?.group(1);
}

/// Junta los `<t>` de una celda de texto (el texto puede venir en trozos).
String _textosDe(String xml) {
  final sb = StringBuffer();
  for (final t in RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(xml)) {
    sb.write(_desescapar(t.group(1)!));
  }
  return sb.toString();
}

String _desescapar(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
      final n = int.tryParse(m.group(2)!, radix: m.group(1) == 'x' ? 16 : 10);
      return n == null ? m.group(0)! : String.fromCharCode(n);
    })
    .replaceAll('&amp;', '&');
