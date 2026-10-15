import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga un texto como archivo desde el navegador. Con BOM para que Excel
/// abra bien las tildes.
void descargarTexto(String nombre, String contenido, {String tipo = 'text/csv'}) {
  final bytes = Uint8List.fromList(utf8.encode('﻿$contenido'));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$tipo;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nombre;
  enlace.click();
  web.URL.revokeObjectURL(url);
}

/// Una fila CSV (separador `;`, el que espera Excel en español). Las celdas
/// que empiezan por `= + - @` se neutralizan para que Excel no las ejecute
/// como fórmula.
String filaCsv(Iterable<Object?> celdas) => celdas.map((c) {
      var t = '${c ?? ''}';
      if (t.isNotEmpty && '=+-@'.contains(t[0]) && double.tryParse(t) == null) {
        t = "'$t";
      }
      return '"${t.replaceAll('"', '""')}"';
    }).join(';');
