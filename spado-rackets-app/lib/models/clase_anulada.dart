import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

/// Por qué no se pudo dar la clase. Siempre es algo ajeno a la persona que
/// debía venir: por eso no cuenta como falta y queda pendiente de recuperar.
enum MotivoAnulacion {
  clima('Mal tiempo (lluvia, viento…)', 'por mal tiempo'),
  pista('Pista no disponible', 'porque la pista no estaba disponible'),
  entrenador('Entrenador no disponible', 'porque el entrenador no pudo darla'),
  otro('Otro motivo', 'por un motivo ajeno a la alumna');

  const MotivoAnulacion(this.etiqueta, this.frase);
  final String etiqueta;

  /// Para completar "La clase se anuló …".
  final String frase;

  static MotivoAnulacion fromString(String? v) => MotivoAnulacion.values
      .firstWhere((m) => m.name == v, orElse: () => MotivoAnulacion.otro);
}

/// Documento `clasesAnuladas/{alumnaId}_{yyyy-MM-dd}`: lo que no se pudo dar de
/// la clase de una persona ese día (entera o solo una parte) y cuánto de eso
/// se ha recuperado ya.
class ClaseAnulada {
  const ClaseAnulada({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.grupo,
    required this.familiaUid,
    required this.fecha,
    required this.minutos,
    required this.motivo,
    this.nota = '',
    this.recuperados = 0,
    this.creadoPorNombre = '',
  });

  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String grupo;
  final String familiaUid;

  /// `yyyy-MM-dd`.
  final String fecha;

  /// Minutos de clase que no se dieron.
  final int minutos;
  final MotivoAnulacion motivo;
  final String nota;

  /// Minutos ya recuperados.
  final int recuperados;
  final String creadoPorNombre;

  int get pendientes => (minutos - recuperados).clamp(0, minutos);
  bool get recuperada => pendientes == 0;

  static String idPara(String alumnaId, String fecha) => '${alumnaId}_$fecha';

  factory ClaseAnulada.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ClaseAnulada(
      id: doc.id,
      alumnaId: (d['alumnaId'] as String?) ?? '',
      alumnaNombre: (d['alumnaNombre'] as String?) ?? '',
      grupo: (d['grupo'] as String?) ?? '',
      familiaUid: (d['familiaUid'] as String?) ?? '',
      fecha: (d['fecha'] as String?) ?? '',
      minutos: (d['minutos'] as num?)?.toInt() ?? 0,
      motivo: MotivoAnulacion.fromString(d['motivo'] as String?),
      nota: (d['nota'] as String?) ?? '',
      recuperados: (d['recuperados'] as num?)?.toInt() ?? 0,
      creadoPorNombre: (d['creadoPorNombre'] as String?) ?? '',
    );
  }
}

/// `90` → `1 h 30`, `45` → `45 min`, `120` → `2 h`.
String duracionTexto(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m';
}
