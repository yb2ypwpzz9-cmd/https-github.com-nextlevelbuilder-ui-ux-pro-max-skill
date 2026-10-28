import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import 'excel_export.dart';

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

/// Descarga un archivo binario (p. ej. un .xlsx) desde el navegador.
void descargarBytes(String nombre, Uint8List bytes, String tipo) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: tipo));
  final url = web.URL.createObjectURL(blob);
  final enlace = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nombre;
  enlace.click();
  web.URL.revokeObjectURL(url);
}

/// Genera y descarga un Excel con la fecha de hoy en el nombre.
void descargarExcel(String nombre, Map<String, List<List<Object?>>> hojas) {
  final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
  descargarBytes(
    'spado-rackets-$nombre-$fecha.xlsx',
    construirXlsx(hojas),
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}

/// Fuerza a este dispositivo a bajar la última versión: borra el service worker
/// y las cachés de la app y recarga la página. Es lo que hay que hacer si un
/// móvil se queda con una versión vieja.
Future<void> recargarApp() async {
  try {
    final registros =
        (await web.window.navigator.serviceWorker.getRegistrations().toDart)
            .toDart;
    for (final r in registros) {
      await r.unregister().toDart;
    }
    final claves = (await web.window.caches.keys().toDart).toDart;
    for (final k in claves) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {
    // Si el navegador no lo permite, al menos se recarga.
  }
  web.window.location.reload();
}

/// Alto en píxeles lógicos de la zona inferior que reserva el sistema (el
/// indicador de inicio del iPhone, ~34). Flutter web no lo da en
/// `MediaQuery.padding`, así que se lee del CSS `env(safe-area-inset-bottom)`.
/// Los toques dentro de esa franja los retrasa o los cancela iOS: los botones
/// no deben estar ahí. Fuera de un iPhone instalado vale 0.
double margenInferiorDelSistema() {
  try {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.style.cssText = 'position:fixed;left:0;bottom:0;width:0;height:0;'
        'visibility:hidden;padding-bottom:env(safe-area-inset-bottom)';
    web.document.body!.append(div);
    final texto = web.window.getComputedStyle(div).paddingBottom;
    div.remove();
    final valor = double.tryParse(texto.replaceAll('px', '')) ?? 0;
    return valor.clamp(0, 80).toDouble();
  } catch (_) {
    return 0;
  }
}
