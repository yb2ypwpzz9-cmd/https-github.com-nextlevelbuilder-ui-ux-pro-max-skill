import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

/// Documento `alumnas/{id}`.
///
/// `familiaUid` lo escribe sólo el servidor (`vincularAlumna`), al canjear el
/// código que el club entrega a la familia. Si lo pudiera escribir la app,
/// cualquiera se apuntaría como familia de una menor ajena.
class Alumna {
  const Alumna({
    required this.id,
    required this.nombre,
    required this.grupo,
    this.familiaUid,
    this.fechaNacimiento,
    this.activa = true,
  });

  final String id;
  final String nombre;
  final String grupo;
  final String? familiaUid;
  final DateTime? fechaNacimiento;
  final bool activa;

  factory Alumna.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final familia = (data['familiaUid'] as String?)?.trim();
    return Alumna(
      id: doc.id,
      nombre: (data['nombre'] as String?)?.trim().isNotEmpty ?? false
          ? (data['nombre'] as String).trim()
          : 'Alumna',
      grupo: (data['grupo'] as String?) ?? '',
      familiaUid: familia == null || familia.isEmpty ? null : familia,
      fechaNacimiento: fechaDe(data['fechaNacimiento']),
      activa: (data['activa'] as bool?) ?? true,
    );
  }

  String get nombreCorto => nombre.split(' ').first;
  bool get vinculada => familiaUid != null;
}

/// Documento `codigosVinculacion/{id}`. Sólo lo lee Dirección.
class CodigoVinculacion {
  const CodigoVinculacion({
    required this.id,
    required this.codigo,
    required this.alumnaId,
    this.usadoPor,
  });

  final String id;
  final String codigo;
  final String alumnaId;
  final String? usadoPor;

  bool get usado => usadoPor != null && usadoPor!.isNotEmpty;

  factory CodigoVinculacion.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CodigoVinculacion(
      id: doc.id,
      codigo: (data['codigo'] as String?) ?? '',
      alumnaId: (data['alumnaId'] as String?) ?? '',
      usadoPor: data['usadoPor'] as String?,
    );
  }
}
