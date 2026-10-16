import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;

/// Reduce una foto a 480 px de ancho máximo y la pasa a JPEG: pesa unas
/// decenas de KB, carga al instante en el móvil y no guarda los datos del
/// archivo original (ubicación, modelo de cámara…). Devuelve `null` si el
/// archivo no se puede leer como imagen.
///
/// Se hace con el propio navegador, que aguanta fotos enormes (48 MP) sin
/// problema y las gira bien; si falla, se intenta en Dart.
Future<Uint8List?> prepararFoto(Uint8List original) async {
  final delNavegador = await _reducirConNavegador(original);
  if (delNavegador != null) return delNavegador;
  return _reducirEnDart(original);
}

Future<Uint8List?> _reducirConNavegador(Uint8List original) async {
  String? url;
  try {
    final blob = web.Blob([original.toJS].toJS);
    url = web.URL.createObjectURL(blob);
    final imagen = web.HTMLImageElement()..src = url;
    await imagen.decode().toDart;
    final ancho = imagen.naturalWidth;
    final alto = imagen.naturalHeight;
    if (ancho <= 0 || alto <= 0) return null;
    final escala = ancho > 480 ? 480 / ancho : 1.0;
    final canvas = web.HTMLCanvasElement()
      ..width = (ancho * escala).round()
      ..height = (alto * escala).round();
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(imagen, 0, 0, canvas.width.toDouble(), canvas.height.toDouble());

    final listo = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) => listo.complete(b)).toJS,
      'image/jpeg',
      0.82.toJS,
    );
    final resultado = await listo.future;
    if (resultado == null) return null;
    final buffer = await resultado.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  } finally {
    if (url != null) web.URL.revokeObjectURL(url);
  }
}

Uint8List? _reducirEnDart(Uint8List original) {
  try {
    final decodificada = img.decodeImage(original);
    if (decodificada == null) return null;
    final orientada = img.bakeOrientation(decodificada);
    final reducida = orientada.width > 480
        ? img.copyResize(orientada, width: 480)
        : orientada;
    return Uint8List.fromList(img.encodeJpg(reducida, quality: 82));
  } catch (_) {
    return null;
  }
}
