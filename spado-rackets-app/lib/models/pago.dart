import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../config/club_config.dart';
import '../services/firestore_refs.dart';

enum EstadoPago {
  pendiente,
  enRevision,
  pagado,
  rechazado;

  static EstadoPago fromString(String? value) => switch (value) {
        'en_revision' => EstadoPago.enRevision,
        'pagado' => EstadoPago.pagado,
        'rechazado' => EstadoPago.rechazado,
        _ => EstadoPago.pendiente,
      };

  String get wire => switch (this) {
        EstadoPago.enRevision => 'en_revision',
        _ => name,
      };

  String get label => switch (this) {
        EstadoPago.pendiente => 'Pendiente',
        EstadoPago.enRevision => 'En revisión',
        EstadoPago.pagado => 'Pagada',
        EstadoPago.rechazado => 'Rechazada',
      };
}

/// Documento `pagos/{alumnaId}_{yyyy-MM}`: la cuota de un mes.
///
/// Flujo: Dirección genera las cuotas del mes → la familia transfiere y sube
/// el justificante (pasa a "en revisión") → Dirección la marca pagada o la
/// rechaza con un motivo. Dirección también puede registrar un cobro en
/// efectivo directamente como pagado.
class Pago {
  const Pago({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.grupo,
    required this.familiaUid,
    required this.periodo,
    required this.importe,
    required this.moneda,
    required this.estado,
    this.concepto = 'Cuota mensual',
    this.comprobantePath,
    this.comprobanteNombre,
    this.subidoEn,
    this.motivoRechazo,
    this.resueltoEn,
    this.resueltoPorNombre,
    this.registradoAMano = false,
    this.metodo,
    this.historico = false,
    this.venceEn,
  });

  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String grupo;
  final String familiaUid;

  /// `yyyy-MM`.
  final String periodo;
  final double importe;
  final Moneda moneda;
  final EstadoPago estado;
  final String concepto;

  /// Ruta en Storage (`comprobantes/{uid}/...`). Se guarda la ruta y no una
  /// URL pública: el archivo sólo se puede abrir si las reglas lo permiten.
  final String? comprobantePath;
  final String? comprobanteNombre;
  final DateTime? subidoEn;
  final String? motivoRechazo;
  final DateTime? resueltoEn;
  final String? resueltoPorNombre;
  final bool registradoAMano;

  /// `transferencia` o `efectivo` en las cuotas cargadas del histórico.
  final String? metodo;

  /// Cuota de un mes anterior cargada por Dirección (nunca se avisó a la familia).
  final bool historico;

  /// Plazo propio de esta cuota. Sin él, vale el día 5 del mes.
  final DateTime? venceEn;

  static String idPara(String alumnaId, String periodo) => '${alumnaId}_$periodo';

  factory Pago.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Pago(
      id: doc.id,
      alumnaId: (data['alumnaId'] as String?) ?? '',
      alumnaNombre: (data['alumnaNombre'] as String?) ?? 'Alumna',
      grupo: (data['grupo'] as String?) ?? '',
      familiaUid: (data['familiaUid'] as String?) ?? '',
      periodo: (data['periodo'] as String?) ?? '',
      importe: (data['importe'] as num?)?.toDouble() ?? 0,
      // Las cuotas son siempre en dólares, aunque un documento antiguo diga otra cosa.
      moneda: ClubConfig.monedaPorDefecto,
      estado: EstadoPago.fromString(data['estado'] as String?),
      concepto: (data['concepto'] as String?) ?? 'Cuota mensual',
      comprobantePath: data['comprobantePath'] as String?,
      comprobanteNombre: data['comprobanteNombre'] as String?,
      subidoEn: fechaDe(data['subidoEn']),
      motivoRechazo: data['motivoRechazo'] as String?,
      resueltoEn: fechaDe(data['resueltoEn']),
      resueltoPorNombre: data['resueltoPorNombre'] as String?,
      registradoAMano: (data['registradoAMano'] as bool?) ?? false,
      metodo: data['metodo'] as String?,
      historico: (data['historico'] as bool?) ?? false,
      venceEn: _fechaClaveODoc(data['venceEn']),
    );
  }

  /// La familia tiene algo que hacer: pagar, o volver a subir el justificante.
  bool get necesitaAccionFamilia =>
      estado == EstadoPago.pendiente || estado == EstadoPago.rechazado;

  /// Cómo se cobró, para los informes.
  String get formaDePago {
    if (metodo == 'efectivo' || registradoAMano) return 'Efectivo';
    if (metodo == 'transferencia' || tieneComprobante) return 'Transferencia';
    return '';
  }

  bool get tieneComprobante =>
      comprobantePath != null && comprobantePath!.isNotEmpty;

  DateTime? get inicioPeriodo {
    final partes = periodo.split('-');
    if (partes.length != 2) return null;
    final anio = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    if (anio == null || mes == null || mes < 1 || mes > 12) return null;
    return DateTime(anio, mes);
  }

  DateTime? get fechaLimite {
    if (venceEn != null) return venceEn;
    final inicio = inicioPeriodo;
    if (inicio == null) return null;
    return DateTime(inicio.year, inicio.month, ClubConfig.diaVencimientoCuota);
  }

  /// Vencida: sin cobrar y pasado el día límite.
  bool vencidaEn(DateTime momento) {
    if (!necesitaAccionFamilia) return false;
    final limite = fechaLimite;
    if (limite == null) return false;
    final hoy = DateTime(momento.year, momento.month, momento.day);
    return hoy.isAfter(limite);
  }

  String get periodoLabel => etiquetaPeriodo(periodo);
}

/// `yyyy-MM-dd` → fecha; cualquier otra cosa → `null`.
DateTime? _fechaClaveODoc(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
      int.parse(m.group(3)!));
}

final _mesAnio = DateFormat('MMMM y', 'es');

/// `2026-10` → `Octubre 2026`.
String etiquetaPeriodo(String periodo) {
  final partes = periodo.split('-');
  if (partes.length != 2) return periodo;
  final anio = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  if (anio == null || mes == null || mes < 1 || mes > 12) return periodo;
  final texto = _mesAnio.format(DateTime(anio, mes));
  return texto[0].toUpperCase() + texto.substring(1);
}

String periodoDe(DateTime fecha) =>
    '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';

/// `US$ 150.00` — coma de miles, punto decimal.
String formatoImporte(double importe, Moneda moneda) {
  final f = NumberFormat('#,##0.00', 'en_US');
  return '${moneda.simbolo} ${f.format(importe)}';
}

/// Una cuenta bancaria del club para las transferencias.
class CuentaBancaria {
  const CuentaBancaria({
    required this.banco,
    required this.numero,
    required this.titular,
    this.tipo = 'Corriente',
    this.documento = '',
    this.moneda = ClubConfig.monedaPorDefecto,
  });

  final String banco;
  final String numero;
  final String titular;

  /// Corriente o ahorros.
  final String tipo;

  /// RNC o cédula del titular: muchos bancos dominicanos lo piden para
  /// transferir a terceros.
  final String documento;
  final Moneda moneda;

  factory CuentaBancaria.fromMap(Map<dynamic, dynamic> m) => CuentaBancaria(
        banco: (m['banco'] as String?) ?? '',
        numero: (m['numero'] as String?) ?? '',
        titular: (m['titular'] as String?) ?? '',
        tipo: (m['tipo'] as String?) ?? 'Corriente',
        documento: (m['documento'] as String?) ?? '',
        moneda: Moneda.fromString(m['moneda'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'banco': banco,
        'numero': numero,
        'titular': titular,
        'tipo': tipo,
        'documento': documento,
        'moneda': moneda.wire,
      };
}

/// Documento `ajustes/club`.
class AjustesClub {
  const AjustesClub({
    this.cuentas = const [],
    this.instrucciones = '',
    this.cuotasAuto = 'off',
  });

  /// Cuentas oficiales del club. Se muestran mientras Dirección no haya
  /// guardado otras desde la app (Más → Datos bancarios).
  static const cuentasOficiales = [
    CuentaBancaria(
      banco: 'Banco Popular',
      numero: '9602246400',
      titular: 'Alfonso José García Gama',
      tipo: 'Cuenta de ahorro',
      documento: 'Pasaporte PAQ896638',
      moneda: Moneda.dop,
    ),
    CuentaBancaria(
      banco: 'Banreservas',
      numero: '9602257772',
      titular: 'Alfonso José García Gama',
      tipo: 'Cuenta de ahorro',
      documento: 'Pasaporte PAQ896638',
      moneda: Moneda.usd,
    ),
  ];

  static const instruccionesOficiales =
      'El pago debe realizarse dentro de los 5 primeros días de cada mes. '
      'En el concepto indica el nombre de la alumna y el mes.';

  final List<CuentaBancaria> cuentas;

  /// Texto libre que ve la familia junto a las cuentas, por ejemplo qué poner
  /// en el concepto de la transferencia.
  final String instrucciones;

  /// Qué pasa el día 1 de cada mes: `off` (Dirección las genera a mano),
  /// `aviso` (se avisa a Dirección) o `auto` (se generan solas).
  final String cuotasAuto;

  bool get tieneCuentas => cuentas.isNotEmpty;

  factory AjustesClub.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final cuentas = [
      for (final c in (data['cuentas'] as List<dynamic>? ?? const []))
        if (c is Map) CuentaBancaria.fromMap(c),
    ];
    final auto = data['cuotasAuto'];
    return AjustesClub(
      cuotasAuto: auto == 'auto' || auto == 'aviso' ? auto as String : 'off',
      cuentas: cuentas.isEmpty ? cuentasOficiales : cuentas,
      instrucciones: cuentas.isEmpty
          ? instruccionesOficiales
          : (data['instrucciones'] as String?) ?? '',
    );
  }
}
