import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

/// Documento `jornadas/{id}`: el fichaje de entrada y salida de una persona
/// del staff.
///
/// Las dos horas las pone el SERVIDOR (`FieldValue.serverTimestamp`) y las
/// reglas exigen que coincidan con `request.time`: con la hora del móvil, bastaría
/// con adelantar el reloj para fichar a las cinco llegando a las seis. Una vez
/// cerrada, la jornada no se puede editar desde la app.
class Jornada {
  const Jornada({
    required this.id,
    required this.staffUid,
    required this.staffNombre,
    required this.entrada,
    this.salida,
    this.entradaLat,
    this.entradaLng,
    this.entradaPrecision,
    this.salidaLat,
    this.salidaLng,
    this.salidaPrecision,
  });

  final String id;
  final String staffUid;
  final String staffNombre;
  final DateTime entrada;
  final DateTime? salida;
  final double? entradaLat;
  final double? entradaLng;
  final double? entradaPrecision;
  final double? salidaLat;
  final double? salidaLng;
  final double? salidaPrecision;


  Duration duracionHasta(DateTime ahora) =>
      (salida ?? ahora).difference(entrada);

  bool get entradaConUbicacion => entradaLat != null && entradaLng != null;

  /// Enlace a Google Maps con la posición de entrada, para que Dirección pueda
  /// comprobar dónde fichó.
  Uri? get mapaEntrada => entradaConUbicacion
      ? Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$entradaLat,$entradaLng')
      : null;

  factory Jornada.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    double? num_(String k) => (data[k] as num?)?.toDouble();
    return Jornada(
      id: doc.id,
      staffUid: (data['staffUid'] as String?) ?? '',
      staffNombre: (data['staffNombre'] as String?) ?? 'Staff',
      // Recién escrita, la hora del servidor aún no ha vuelto: se usa la local
      // sólo para pintar, nunca se guarda.
      entrada: fechaDe(data['entrada']) ?? DateTime.now(),
      salida: fechaDe(data['salida']),
      entradaLat: num_('entradaLat'),
      entradaLng: num_('entradaLng'),
      entradaPrecision: num_('entradaPrecision'),
      salidaLat: num_('salidaLat'),
      salidaLng: num_('salidaLng'),
      salidaPrecision: num_('salidaPrecision'),
    );
  }
}

/// "3 h 05 min"
String formatoDuracion(Duration d) {
  final minutos = d.inMinutes < 0 ? 0 : d.inMinutes;
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

/// Suma de horas de una lista de jornadas, contando las abiertas hasta [ahora].
Duration totalTrabajado(Iterable<Jornada> jornadas, DateTime ahora) =>
    jornadas.fold(Duration.zero, (acc, j) => acc + j.duracionHasta(ahora));
