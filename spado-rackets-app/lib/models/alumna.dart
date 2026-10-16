import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

/// Tipo de jugador: sirve para hablar con propiedad (niña, niño, adulto) en
/// vez de ponerlo todo en femenino.
enum TipoJugador {
  nina('Niña'),
  nino('Niño'),
  adulto('Adulto');

  const TipoJugador(this.label);
  final String label;

  static TipoJugador? fromString(String? v) {
    for (final t in TipoJugador.values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

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
    this.tipo,
    this.dias = const [],
    this.horaInicio = '',
    this.duracionMinutos = 60,
    this.cuotaMensual = 0,
    this.contactoNombre,
    this.contactoTelefono,
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
  final TipoJugador? tipo;

  /// Días de clase propios, 1 = lunes … 7 = domingo.
  final List<int> dias;

  /// Hora de inicio `HH:mm` y duración de su clase.
  final String horaInicio;
  final int duracionMinutos;

  /// Cuota mensual propia, en dólares.
  final double cuotaMensual;

  /// Persona de contacto (madre, padre, tutor o la propia persona) y su
  /// teléfono, para avisar a la familia. Son opcionales: si la familia se
  /// registra, se rellenan con los datos de su cuenta.
  final String? contactoNombre;
  final String? contactoTelefono;

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
      tipo: TipoJugador.fromString(data['tipo'] as String?),
      dias: [
        for (final d in (data['dias'] as List<dynamic>? ?? const []))
          if (d is num && d >= 1 && d <= 7) d.toInt(),
      ]..sort(),
      horaInicio: (data['horaInicio'] as String?) ?? '',
      duracionMinutos: (data['duracionMinutos'] as num?)?.toInt() ?? 60,
      cuotaMensual: (data['cuotaMensual'] as num?)?.toDouble() ?? 0,
      contactoNombre: (data['contactoNombre'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['contactoNombre'] as String).trim(),
      contactoTelefono:
          (data['contactoTelefono'] as String?)?.trim().isEmpty ?? true
              ? null
              : (data['contactoTelefono'] as String).trim(),
      fotoPath: (data['fotoPath'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['fotoPath'] as String).trim(),
      activa: (data['activa'] as bool?) ?? true,
    );
  }

  String get nombreCorto => nombre.split(' ').first;

  bool tieneClaseEl(DateTime dia) => dias.contains(dia.weekday);

  static const _nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  /// "Lun · Mié · 17:30", o "Sin horario".
  String get horarioTexto {
    if (dias.isEmpty) return 'Sin horario';
    return [
      dias.map((d) => _nombresDias[d - 1]).join(' · '),
      if (horaInicio.isNotEmpty) horaInicio,
    ].join(' · ');
  }
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
