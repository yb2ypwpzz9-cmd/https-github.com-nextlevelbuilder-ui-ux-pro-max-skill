import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

enum CategoriaGasto {
  pistas('Pistas y alquiler'),
  material('Material'),
  personal('Entrenadores y personal'),
  marketing('Marketing'),
  otros('Otros');

  const CategoriaGasto(this.label);
  final String label;

  static CategoriaGasto fromString(String? v) => CategoriaGasto.values
      .firstWhere((c) => c.name == v, orElse: () => CategoriaGasto.otros);
}

/// Documento `gastos/{id}`: un gasto del club, siempre en US$.
class Gasto {
  const Gasto({
    required this.id,
    required this.concepto,
    required this.categoria,
    required this.importe,
    required this.fecha,
  });

  final String id;
  final String concepto;
  final CategoriaGasto categoria;
  final double importe;

  /// `yyyy-MM-dd`.
  final String fecha;

  String get periodo => fecha.length >= 7 ? fecha.substring(0, 7) : fecha;

  factory Gasto.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Gasto(
      id: doc.id,
      concepto: (data['concepto'] as String?) ?? '',
      categoria: CategoriaGasto.fromString(data['categoria'] as String?),
      importe: (data['importe'] as num?)?.toDouble() ?? 0,
      fecha: (data['fecha'] as String?) ?? '',
    );
  }
}
