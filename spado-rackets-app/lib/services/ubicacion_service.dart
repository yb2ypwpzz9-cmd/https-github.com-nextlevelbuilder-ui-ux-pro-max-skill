import 'package:geolocator/geolocator.dart';

/// Resultado de pedir la ubicación al fichar.
sealed class ResultadoUbicacion {
  const ResultadoUbicacion();
}

class UbicacionObtenida extends ResultadoUbicacion {
  const UbicacionObtenida({
    required this.latitud,
    required this.longitud,
    required this.precisionMetros,
  });

  final double latitud;
  final double longitud;
  final double precisionMetros;
}

class UbicacionNoDisponible extends ResultadoUbicacion {
  const UbicacionNoDisponible(this.motivo);

  /// Mensaje ya redactado para el entrenador.
  final String motivo;
}

/// Ubicación del dispositivo al fichar. Misma lógica que Spado Soccer.
class UbicacionService {
  const UbicacionService();

  Future<ResultadoUbicacion> obtener() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const UbicacionNoDisponible(
          'La ubicación del dispositivo está desactivada. Actívala para fichar.',
        );
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        return const UbicacionNoDisponible(
          'El navegador tiene bloqueada la ubicación para esta web. Permítela '
          'en los ajustes del navegador (icono del candado junto a la '
          'dirección) y vuelve a intentarlo.',
        );
      }
      if (permiso == LocationPermission.denied) {
        return const UbicacionNoDisponible(
          'Necesitamos tu ubicación para registrar el fichaje. Acepta el '
          'permiso e inténtalo otra vez.',
        );
      }
    } catch (_) {
      return const UbicacionNoDisponible(
        'Este navegador no permite obtener la ubicación. Prueba con Chrome o '
        'Safari actualizados.',
      );
    }

    final posicion = await _posicionActual();
    if (posicion == null) {
      return const UbicacionNoDisponible(
        'No hemos podido obtener tu ubicación. Comprueba que tienes señal y '
        'vuelve a intentarlo.',
      );
    }
    return UbicacionObtenida(
      latitud: posicion.latitude,
      longitud: posicion.longitude,
      precisionMetros: posicion.accuracy,
    );
  }

  /// Alta precisión primero; si no llega, precisión media. Nunca la última
  /// posición conocida: podría ser la de su casa.
  Future<Position?> _posicionActual() async {
    const intentos = [
      (LocationAccuracy.high, Duration(seconds: 15)),
      (LocationAccuracy.medium, Duration(seconds: 20)),
    ];
    for (final (precision, limite) in intentos) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: precision,
            timeLimit: limite,
          ),
        );
      } catch (_) {
        // Siguiente nivel.
      }
    }
    return null;
  }
}
