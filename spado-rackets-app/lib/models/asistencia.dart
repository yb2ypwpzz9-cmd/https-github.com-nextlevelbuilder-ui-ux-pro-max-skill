import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/firestore_refs.dart';

enum EstadoAsistencia {
  presente('P', 'Asistió'),
  falta('F', 'Falta'),
  justificada('J', 'Justificada');

  const EstadoAsistencia(this.letra, this.label);
  final String letra;
  final String label;

  String get wire => name;

  static EstadoAsistencia? fromString(String? v) => switch (v) {
        'presente' => EstadoAsistencia.presente,
        'falta' => EstadoAsistencia.falta,
        'justificada' => EstadoAsistencia.justificada,
        _ => null,
      };
}

final _fechaClave = DateFormat('yyyy-MM-dd');

/// Fecha de una sesión como clave `yyyy-MM-dd`.
String claveFecha(DateTime dia) => _fechaClave.format(dia);
DateTime fechaDeClave(String clave) => _fechaClave.parse(clave);

/// Documento `asistencias/{grupo}_{fecha}_{alumna}`.
///
/// El id determinista hace que volver a pasar lista el mismo día corrija la
/// marca en vez de duplicarla.
class Asistencia {
  const Asistencia({
    required this.id,
    required this.grupo,
    required this.fecha,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.estado,
    this.marcadoPorNombre,
    this.marcadoEn,
  });

  final String id;
  final String grupo;
  final String fecha;
  final String alumnaId;
  final String alumnaNombre;
  final EstadoAsistencia estado;
  final String? marcadoPorNombre;
  final DateTime? marcadoEn;

  static String idPara(String grupo, String fecha, String alumnaId) =>
      '${grupo}_${fecha}_$alumnaId';

  factory Asistencia.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Asistencia(
      id: doc.id,
      grupo: (data['grupo'] as String?) ?? '',
      fecha: (data['fecha'] as String?) ?? '',
      alumnaId: (data['alumnaId'] as String?) ?? '',
      alumnaNombre: (data['alumnaNombre'] as String?) ?? '',
      estado: EstadoAsistencia.fromString(data['estado'] as String?) ??
          EstadoAsistencia.falta,
      marcadoPorNombre: data['marcadoPorNombre'] as String?,
      marcadoEn: fechaDe(data['marcadoEn']),
    );
  }
}

/// Documento `ausencias/{id}`: la familia avisa de que su hija faltará.
class Ausencia {
  const Ausencia({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.grupo,
    required this.fecha,
    required this.motivo,
  });

  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String grupo;
  final String fecha;
  final String motivo;

  factory Ausencia.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Ausencia(
      id: doc.id,
      alumnaId: (data['alumnaId'] as String?) ?? '',
      alumnaNombre: (data['alumnaNombre'] as String?) ?? '',
      grupo: (data['grupo'] as String?) ?? '',
      fecha: (data['fecha'] as String?) ?? '',
      motivo: (data['motivo'] as String?) ?? '',
    );
  }
}

/// Porcentaje de sesiones a las que asistió. Las justificadas no cuentan en
/// contra: es lo que una familia espera ver si avisó a tiempo.
int porcentajeAsistencia(Iterable<Asistencia> marcas) {
  final contables =
      marcas.where((m) => m.estado != EstadoAsistencia.justificada).toList();
  if (contables.isEmpty) return 100;
  final presentes =
      contables.where((m) => m.estado == EstadoAsistencia.presente).length;
  return (presentes * 100 / contables.length).round();
}
