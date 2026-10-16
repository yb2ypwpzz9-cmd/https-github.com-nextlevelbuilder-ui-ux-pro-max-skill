import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

/// Nivel de tenis de la alumna, para formar grupos y seguir su evolución.
enum NivelTenis {
  iniciacion('Iniciación'),
  basico('Básico'),
  intermedio('Intermedio'),
  avanzado('Avanzado'),
  competicion('Competición');

  const NivelTenis(this.label);
  final String label;

  static NivelTenis? fromString(String? v) {
    for (final n in NivelTenis.values) {
      if (n.name == v) return n;
    }
    return null;
  }
}

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
    this.emailFamilia,
    this.nivel,
    this.fotoPath,
    this.activa = true,
  });

  final String id;
  final String nombre;
  final String grupo;
  final String? familiaUid;
  final DateTime? fechaNacimiento;

  /// Correo que Dirección ha dado de alta para esta familia. Si existe, sólo
  /// ese correo puede usar el código de vinculación.
  final String? emailFamilia;
  final bool activa;
  final NivelTenis? nivel;

  /// Ruta de la foto en Storage (`fotos/{alumna}/…`). La ven la familia, el
  /// staff del grupo y Dirección, nadie más.
  final String? fotoPath;

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
      emailFamilia: (data['emailFamilia'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['emailFamilia'] as String).trim(),
      nivel: NivelTenis.fromString(data['nivel'] as String?),
      fotoPath: (data['fotoPath'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['fotoPath'] as String).trim(),
      activa: (data['activa'] as bool?) ?? true,
    );
  }

  String get nombreCorto => nombre.split(' ').first;
  bool get vinculada => familiaUid != null;

  /// "9 años", o `null` si no se conoce la fecha de nacimiento.
  int? get edad {
    final n = fechaNacimiento;
    if (n == null) return null;
    final hoy = DateTime.now();
    var e = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) e--;
    return e < 0 ? null : e;
  }
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
