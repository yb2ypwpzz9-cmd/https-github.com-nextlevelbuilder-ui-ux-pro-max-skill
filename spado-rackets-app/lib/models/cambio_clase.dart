import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';
import 'alumna.dart';

/// Lo que cambia en un día concreto respecto al horario fijo de una persona.
enum TipoCambio {
  /// Ese día no hay clase (aunque le tocara).
  cancelada,

  /// Ese día sí hay clase, a esa hora (aunque no le tocara, o a otra hora).
  extra,
}

/// Documento `cambiosClase/{alumnaId}_{yyyy-MM-dd}`.
///
/// Un cambio puntual no toca el horario fijo de la ficha: solo afecta a ese
/// día. Para mover una clase de un día a otro hay dos cambios: una
/// `cancelada` el día que no viene y una `extra` el día nuevo.
class CambioClase {
  const CambioClase({
    required this.id,
    required this.alumnaId,
    required this.grupo,
    required this.fecha,
    required this.tipo,
    this.horaInicio = '',
    this.familiaUid = '',
  });

  final String id;
  final String alumnaId;
  final String grupo;

  /// `yyyy-MM-dd`.
  final String fecha;
  final TipoCambio tipo;
  final String horaInicio;
  final String familiaUid;

  static String idPara(String alumnaId, String fecha) => '${alumnaId}_$fecha';

  factory CambioClase.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CambioClase(
      id: doc.id,
      alumnaId: (data['alumnaId'] as String?) ?? '',
      grupo: (data['grupo'] as String?) ?? '',
      fecha: (data['fecha'] as String?) ?? '',
      tipo:
          data['tipo'] == 'cancelada' ? TipoCambio.cancelada : TipoCambio.extra,
      horaInicio: (data['horaInicio'] as String?) ?? '',
      familiaUid: (data['familiaUid'] as String?) ?? '',
    );
  }
}

/// La clase que de verdad hay un día para una persona.
class ClaseDelDia {
  const ClaseDelDia(this.hora, {this.cambiada = false});

  /// `HH:mm`, o vacío si no tiene hora.
  final String hora;
  final bool cambiada;
}

/// Horario fijo + cambio puntual de ese día, si lo hay. `null` = ese día no
/// tiene clase.
ClaseDelDia? claseDelDia(Alumna a, DateTime dia, CambioClase? cambio) {
  if (cambio != null) {
    if (cambio.tipo == TipoCambio.cancelada) return null;
    return ClaseDelDia(
      cambio.horaInicio.isEmpty ? a.horaInicio : cambio.horaInicio,
      cambiada: true,
    );
  }
  return a.tieneClaseEl(dia) ? ClaseDelDia(a.horaDelDia(dia.weekday)) : null;
}
