import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Reduce una foto a 480 px de ancho máximo y la pasa a JPEG: pesa unas
/// decenas de KB, carga al instante en el móvil y no guarda los datos del
/// archivo original (ubicación, modelo de cámara…). Devuelve `null` si el
/// archivo no se puede leer como imagen.
Uint8List? prepararFoto(Uint8List original) {
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
