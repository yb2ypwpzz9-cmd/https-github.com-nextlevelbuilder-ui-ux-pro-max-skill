import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/club_config.dart';
import '../services/firestore_refs.dart';

/// Documento `grupos/{id}`: un grupo de entrenamiento.
class Grupo {
  const Grupo({
    required this.id,
    required this.nombre,
    this.deporte = 'Tenis',
    this.dias = const [],
    this.horaInicio = '',
    this.duracionMinutos = 60,
    this.pista = '',
    this.cuotaMensual = 0,
    this.moneda = ClubConfig.monedaPorDefecto,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String deporte;

  /// Días de clase, 1 = lunes … 7 = domingo (como `DateTime.weekday`).
  final List<int> dias;

  /// Hora de inicio en formato 24 h `HH:mm`.
  final String horaInicio;
  final int duracionMinutos;
  final String pista;
  final double cuotaMensual;
  final Moneda moneda;
  final bool activo;

  static const nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  factory Grupo.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Grupo(
      id: doc.id,
      nombre: (data['nombre'] as String?)?.trim().isNotEmpty ?? false
          ? (data['nombre'] as String).trim()
          : 'Grupo',
      deporte: (data['deporte'] as String?) ?? 'Tenis',
      dias: [
        for (final d in (data['dias'] as List<dynamic>? ?? const []))
          if (d is num && d >= 1 && d <= 7) d.toInt(),
      ]..sort(),
      horaInicio: (data['horaInicio'] as String?) ?? '',
      duracionMinutos: (data['duracionMinutos'] as num?)?.toInt() ?? 60,
      pista: (data['pista'] as String?) ?? '',
      cuotaMensual: (data['cuotaMensual'] as num?)?.toDouble() ?? 0,
      moneda: ClubConfig.monedaPorDefecto,
      activo: (data['activo'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'deporte': deporte,
        'dias': dias,
        'horaInicio': horaInicio,
        'duracionMinutos': duracionMinutos,
        'pista': pista,
        'cuotaMensual': cuotaMensual,
        'moneda': moneda.wire,
        'activo': activo,
      };

  bool tieneClaseEl(DateTime dia) => dias.contains(dia.weekday);

  String get diasTexto =>
      dias.isEmpty ? 'Sin días asignados' : dias.map((d) => nombresDias[d - 1]).join(' · ');

  /// "Lun · Mié · 17:30 · Pista 2"
  String get horarioTexto => [
        diasTexto,
        if (horaInicio.isNotEmpty) horaInicio,
        if (pista.isNotEmpty) pista,
      ].join(' · ');
}
