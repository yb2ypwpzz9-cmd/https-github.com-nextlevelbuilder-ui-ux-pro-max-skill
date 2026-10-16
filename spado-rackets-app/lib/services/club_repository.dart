import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/club_config.dart';
import '../models/alumna.dart';
import '../models/app_user.dart';
import '../models/asistencia.dart';
import '../models/chat.dart';
import '../models/gasto.dart';
import '../models/grupo.dart';
import '../models/jornada.dart';
import '../models/pago.dart';
import 'firestore_refs.dart';
import 'foto_service.dart';
import 'ubicacion_service.dart';

/// Acceso a datos del club. Las pantallas no tocan Firestore directamente.
///
/// Toda consulta va acotada a lo que el usuario puede leer: las reglas de
/// Firestore no filtran resultados, rechazan la consulta entera si alguno no
/// se puede leer.
class GrupoConAlumnasException implements Exception {
  const GrupoConAlumnasException();
}

class ClubRepository {
  const ClubRepository();

  // ------------------------------------------------------------- grupos

  /// Los grupos los puede leer cualquiera con sesión: no hay datos personales.
  Stream<List<Grupo>> watchGrupos() => Refs.grupos
      .orderBy('nombre')
      .snapshots()
      .map((s) => mapearDocs(s.docs, Grupo.fromDoc));

  Future<void> guardarGrupo(Grupo grupo, {bool nuevo = false}) {
    final ref = nuevo ? Refs.grupos.doc() : Refs.grupos.doc(grupo.id);
    return ref.set(grupo.toMap(), SetOptions(merge: true));
  }

  /// Elimina un grupo. Si aún tiene alumnas se rechaza: quedarían sin grupo
  /// y fuera de las listas. El chat del grupo y su vínculo con el staff los
  /// limpia el servidor (`sincronizarGrupo`).
  Future<void> eliminarGrupo(String id) async {
    final con = await Refs.alumnas.where('grupo', isEqualTo: id).limit(1).get();
    if (con.docs.isNotEmpty) {
      throw const GrupoConAlumnasException();
    }
    await Refs.grupos.doc(id).delete();
  }

  // ------------------------------------------------------------- alumnas

  /// Elimina una alumna, su código y sus cuotas sin cobrar. Las cuotas ya
  /// pagadas y la asistencia se conservan: son el histórico contable del club.
  Future<void> eliminarAlumna(String id, {String? fotoPath}) async {
    final sinCobrar = await Refs.pagos
        .where('alumnaId', isEqualTo: id)
        .where('estado', whereIn: [
      EstadoPago.pendiente.wire,
      EstadoPago.rechazado.wire,
      EstadoPago.enRevision.wire,
    ]).get();
    final batch = Refs.db.batch();
    for (final d in sinCobrar.docs) {
      batch.delete(d.reference);
    }
    batch
      ..delete(Refs.codigos.doc(id))
      ..delete(Refs.alumnas.doc(id));
    await batch.commit();
    if (fotoPath != null) await borrarFotoAlumna(fotoPath);
  }

  Stream<List<Alumna>> watchTodasLasAlumnas() => Refs.alumnas
      .orderBy('nombre')
      .snapshots()
      .map((s) => mapearDocs(s.docs, Alumna.fromDoc));

  /// Staff: sólo las de sus grupos (`whereIn` admite hasta 30 valores).
  Stream<List<Alumna>> watchAlumnasDeGrupos(List<String> grupos) {
    if (grupos.isEmpty) return Stream.value(const []);
    return Refs.alumnas
        .where('grupo', whereIn: grupos.take(30).toList())
        .snapshots()
        .map((s) => mapearDocs(s.docs, Alumna.fromDoc)
          ..sort((a, b) => a.nombre.compareTo(b.nombre)));
  }

  Stream<List<Alumna>> watchAlumnasDeFamilia(String uid) => Refs.alumnas
      .where('familiaUid', isEqualTo: uid)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Alumna.fromDoc)
        ..sort((a, b) => a.nombre.compareTo(b.nombre)));

  Stream<List<CodigoVinculacion>> watchCodigos() => Refs.codigos
      .snapshots()
      .map((s) => mapearDocs(s.docs, CodigoVinculacion.fromDoc));

  /// Alta de una alumna con su código de vinculación, en una sola operación.
  Future<String> crearAlumna({
    required String nombre,
    required String grupo,
    String? emailFamilia,
    DateTime? fechaNacimiento,
    NivelTenis? nivel,
    Uint8List? foto,
  }) async {
    final alumna = Refs.alumnas.doc();
    final fotoPath = foto == null ? null : await subirFotoAlumna(alumna.id, foto);
    final codigo = _generarCodigo();
    final batch = Refs.db.batch()
      ..set(alumna, {
        'nombre': nombre.trim(),
        'grupo': grupo,
        'activa': true,
        if (fechaNacimiento != null)
          'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        if (nivel != null) 'nivel': nivel.name,
        if (fotoPath != null) 'fotoPath': fotoPath,
        if ((emailFamilia ?? '').trim().isNotEmpty)
          'emailFamilia': emailFamilia!.trim().toLowerCase(),
        'creadaEn': FieldValue.serverTimestamp(),
      })
      ..set(Refs.codigos.doc(alumna.id), {
        'codigo': codigo,
        'alumnaId': alumna.id,
        'grupo': grupo,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    return codigo;
  }

  Future<void> actualizarAlumna(
    String id, {
    String? nombre,
    String? grupo,
    bool? activa,
    String? emailFamilia,
    DateTime? fechaNacimiento,
    bool quitarFecha = false,
    NivelTenis? nivel,
    bool quitarNivel = false,
    Uint8List? fotoNueva,
    String? fotoAnterior,
    bool quitarFoto = false,
  }) async {
    String? fotoPath;
    if (fotoNueva != null) fotoPath = await subirFotoAlumna(id, fotoNueva);
    await Refs.alumnas.doc(id).update({
        if (fechaNacimiento != null)
          'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        if (quitarFecha) 'fechaNacimiento': FieldValue.delete(),
        if (nivel != null) 'nivel': nivel.name,
        if (quitarNivel) 'nivel': FieldValue.delete(),
        if (fotoPath != null) 'fotoPath': fotoPath,
        if (quitarFoto && fotoPath == null) 'fotoPath': FieldValue.delete(),
        if (emailFamilia != null) 'emailFamilia': emailFamilia.trim().toLowerCase(),
        if (nombre != null) 'nombre': nombre.trim(),
        if (grupo != null) 'grupo': grupo,
        if (activa != null) 'activa': activa,
      });
    if ((fotoNueva != null || quitarFoto) && fotoAnterior != null) {
      await borrarFotoAlumna(fotoAnterior);
    }
  }

  /// Reduce la foto (480 px, JPEG) y la guarda en `fotos/{alumna}/…`.
  Future<String> subirFotoAlumna(String alumnaId, Uint8List original) async {
    final jpg = prepararFoto(original);
    if (jpg == null) {
      throw Exception('No se pudo leer la imagen. Prueba con un JPG o PNG.');
    }
    final ruta = 'fotos/$alumnaId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await FirebaseStorage.instance
        .ref(ruta)
        .putData(jpg, SettableMetadata(contentType: 'image/jpeg'));
    return ruta;
  }

  Future<void> borrarFotoAlumna(String ruta) async {
    try {
      await FirebaseStorage.instance.ref(ruta).delete();
    } catch (_) {
      // Ya no existía: nada que limpiar.
    }
  }

  static final Map<String, Future<Uint8List?>> _fotos = {};

  /// Bytes de la foto, con caché en memoria para no descargarla en cada
  /// pantalla. Las reglas de Storage deciden quién puede verla.
  Future<Uint8List?> fotoAlumna(String ruta) => _fotos.putIfAbsent(
        ruta,
        () => FirebaseStorage.instance
            .ref(ruta)
            .getData(2 * 1024 * 1024)
            .catchError((_) => null),
      );

  /// Seis caracteres sin los que se confunden al dictarlos (0/O, 1/I/L).
  static String _generarCodigo() {
    const letras = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => letras[r.nextInt(letras.length)]).join();
  }

  // ------------------------------------------------------------ jornadas

  /// El fichaje de hoy, si ya lo hizo. Hay uno por persona y día.
  Stream<Jornada?> watchFichajeHoy(String uid) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    return Refs.jornadas
        .where('staffUid', isEqualTo: uid)
        .where('entrada', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : Jornada.fromDoc(s.docs.first));
  }

  Stream<List<Jornada>> watchMisJornadas(String uid, DateTime desde) =>
      Refs.jornadas
          .where('staffUid', isEqualTo: uid)
          .where('entrada', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
          .orderBy('entrada', descending: true)
          .snapshots()
          .map((s) => mapearDocs(s.docs, Jornada.fromDoc));

  /// Dirección: todas las jornadas desde una fecha.
  Stream<List<Jornada>> watchJornadasDesde(DateTime desde) => Refs.jornadas
      .where('entrada', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
      .orderBy('entrada', descending: true)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Jornada.fromDoc));

  /// Fichaje de llegada del entrenador. El id lleva la fecha: fichar dos
  /// veces el mismo día no crea un segundo registro (las reglas rechazan la
  /// segunda escritura).
  Future<void> ficharLlegada(AppUser user, UbicacionObtenida? u) {
    final d = DateTime.now();
    final fecha = claveFecha(d);
    return Refs.jornadas.doc('${user.uid}_$fecha').set({
      'staffUid': user.uid,
      'staffNombre': user.nombreVisible,
      'fecha': fecha,
      'entrada': FieldValue.serverTimestamp(),
      if (u != null) ...{
        'entradaLat': u.latitud,
        'entradaLng': u.longitud,
        'entradaPrecision': u.precisionMetros,
      },
    });
  }

  // ---------------------------------------------------------- asistencia

  Stream<List<Asistencia>> watchSesion(String grupo, String fecha) =>
      Refs.asistencias
          .where('grupo', isEqualTo: grupo)
          .where('fecha', isEqualTo: fecha)
          .snapshots()
          .map((s) => mapearDocs(s.docs, Asistencia.fromDoc));

  /// Club: marcas de un grupo desde una fecha, para el resumen.
  Stream<List<Asistencia>> watchAsistenciaGrupo(String grupo, String desde) =>
      Refs.asistencias
          .where('grupo', isEqualTo: grupo)
          .where('fecha', isGreaterThanOrEqualTo: desde)
          .orderBy('fecha', descending: true)
          .snapshots()
          .map((s) => mapearDocs(s.docs, Asistencia.fromDoc));

  /// Dirección: todas las marcas desde una fecha.
  Stream<List<Asistencia>> watchAsistenciaDesde(String desde) => Refs
      .asistencias
      .where('fecha', isGreaterThanOrEqualTo: desde)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Asistencia.fromDoc));

  /// Familia: sólo las marcas de sus hijas. El filtro por `familiaUid` es
  /// obligatorio: es lo que hace que la consulta pase las reglas.
  Stream<List<Asistencia>> watchAsistenciaFamilia(String uid) => Refs
      .asistencias
      .where('familiaUid', isEqualTo: uid)
      .orderBy('fecha', descending: true)
      .limit(120)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Asistencia.fromDoc));

  Future<void> guardarLista({
    required Grupo grupo,
    required String fecha,
    required List<Alumna> alumnas,
    required Map<String, EstadoAsistencia> marcas,
    required AppUser quien,
  }) async {
    final batch = Refs.db.batch();
    for (final a in alumnas) {
      final estado = marcas[a.id];
      if (estado == null) continue;
      batch.set(Refs.asistencias.doc(Asistencia.idPara(grupo.id, fecha, a.id)), {
        'grupo': grupo.id,
        'fecha': fecha,
        'alumnaId': a.id,
        'alumnaNombre': a.nombre,
        // Copiado de la ficha para que la familia pueda consultar sus marcas
        // sin leer fichas ajenas. Las reglas comprueban que coincide.
        'familiaUid': a.familiaUid ?? '',
        'estado': estado.wire,
        'marcadoPor': quien.uid,
        'marcadoPorNombre': quien.nombreVisible,
        'marcadoEn': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ------------------------------------------------------------ ausencias

  Stream<List<Ausencia>> watchAusenciasSesion(String grupo, String fecha) =>
      Refs.ausencias
          .where('grupo', isEqualTo: grupo)
          .where('fecha', isEqualTo: fecha)
          .snapshots()
          .map((s) => mapearDocs(s.docs, Ausencia.fromDoc));

  Stream<List<Ausencia>> watchAusenciasFamilia(String uid) => Refs.ausencias
      .where('familiaUid', isEqualTo: uid)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Ausencia.fromDoc));

  Future<void> avisarAusencia({
    required Alumna alumna,
    required String fecha,
    required String motivo,
    required AppUser familia,
  }) =>
      Refs.ausencias.doc('${alumna.id}_$fecha').set({
        'alumnaId': alumna.id,
        'alumnaNombre': alumna.nombre,
        'grupo': alumna.grupo,
        'familiaUid': familia.uid,
        'fecha': fecha,
        'motivo': motivo.trim(),
        'creadaEn': FieldValue.serverTimestamp(),
      });

  // ---------------------------------------------------------------- pagos

  Stream<List<Pago>> watchPagosFamilia(String uid) => Refs.pagos
      .where('familiaUid', isEqualTo: uid)
      .orderBy('periodo', descending: true)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Pago.fromDoc));

  Stream<List<Pago>> watchPagosPeriodo(String periodo) => Refs.pagos
      .where('periodo', isEqualTo: periodo)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Pago.fromDoc)
        ..sort((a, b) => a.alumnaNombre.compareTo(b.alumnaNombre)));

  Stream<List<Pago>> watchPagosEnRevision() => Refs.pagos
      .where('estado', isEqualTo: EstadoPago.enRevision.wire)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Pago.fromDoc));

  Stream<List<Pago>> watchPagosSinCobrar() => Refs.pagos
      .where('estado', whereIn: [
        EstadoPago.pendiente.wire,
        EstadoPago.rechazado.wire,
      ])
      .snapshots()
      .map((s) => mapearDocs(s.docs, Pago.fromDoc));

  /// Dirección: todas las cuotas desde un mes (`yyyy-MM`), para el cuadro de
  /// mandos.
  Stream<List<Pago>> watchPagosDesde(String periodo) => Refs.pagos
      .where('periodo', isGreaterThanOrEqualTo: periodo)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Pago.fromDoc));

  // --------------------------------------------------------------- gastos

  Stream<List<Gasto>> watchGastosDesde(String fecha) => Refs.gastos
      .where('fecha', isGreaterThanOrEqualTo: fecha)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Gasto.fromDoc)
        ..sort((a, b) => b.fecha.compareTo(a.fecha)));

  Future<void> registrarGasto({
    required String concepto,
    required CategoriaGasto categoria,
    required double importe,
    required String fecha,
    required String porUid,
  }) =>
      Refs.gastos.add({
        'concepto': concepto.trim(),
        'categoria': categoria.name,
        'importe': importe,
        'fecha': fecha,
        'creadoEn': FieldValue.serverTimestamp(),
        'creadoPor': porUid,
      });

  Future<void> borrarGasto(String id) => Refs.gastos.doc(id).delete();

  /// Cuotas ya creadas de un mes (ids), para no duplicarlas.
  Future<Set<String>> idsDeCuotas(String periodo) => Refs.pagos
      .where('periodo', isEqualTo: periodo)
      .get()
      .then((s) => s.docs.map((d) => d.id).toSet());

  /// Crea los avisos de cuota indicados. Nunca toca una cuota existente:
  /// volver a pulsar el botón no pisa un pago ya cobrado. Si la alumna aún no
  /// tiene cuenta de familia, la cuota se crea igualmente y se asocia a la
  /// familia cuando esta se registre (función `sincronizarAlumna`).
  /// Devuelve cuántas se crearon.
  Future<int> generarCuotas({
    required String periodo,
    required List<CuotaNueva> cuotas,
  }) async {
    final existentes = await idsDeCuotas(periodo);
    final batch = Refs.db.batch();
    var creadas = 0;
    for (final c in cuotas) {
      final id = Pago.idPara(c.alumna.id, periodo);
      if (existentes.contains(id) || c.importe <= 0) continue;
      batch.set(Refs.pagos.doc(id), {
        'alumnaId': c.alumna.id,
        'alumnaNombre': c.alumna.nombre,
        'grupo': c.alumna.grupo,
        'familiaUid': c.alumna.familiaUid ?? '',
        'periodo': periodo,
        'concepto': c.concepto,
        'importe': c.importe,
        'moneda': ClubConfig.monedaPorDefecto.wire,
        'estado': EstadoPago.pendiente.wire,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      creadas++;
    }
    if (creadas > 0) await batch.commit();
    return creadas;
  }

  /// Sube el justificante y pasa la cuota a revisión.
  ///
  /// La carpeta lleva el uid de quien sube: las reglas de Storage sólo dejan
  /// escribir en la propia, así que nadie puede pisar el justificante de otra
  /// familia.
  Future<void> subirComprobante({
    required Pago pago,
    required String uid,
    required Uint8List bytes,
    required String nombreArchivo,
    required String contentType,
  }) async {
    final extensionBruta = nombreArchivo.contains('.')
        ? nombreArchivo.split('.').last.toLowerCase()
        : '';
    // Solo letras y números: el nombre del archivo viaja dentro de la ruta.
    final extensionLimpia = extensionBruta.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final extension = extensionLimpia.isEmpty || extensionLimpia.length > 5
        ? (contentType == 'application/pdf' ? 'pdf' : 'jpg')
        : extensionLimpia;
    final ruta =
        'comprobantes/$uid/${pago.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await FirebaseStorage.instance
        .ref(ruta)
        .putData(bytes, SettableMetadata(contentType: contentType));

    await Refs.pagos.doc(pago.id).update({
      'comprobantePath': ruta,
      'comprobanteNombre': nombreArchivo.length > 120
          ? nombreArchivo.substring(0, 120)
          : nombreArchivo,
      'estado': EstadoPago.enRevision.wire,
      'subidoEn': FieldValue.serverTimestamp(),
      'motivoRechazo': null,
    });
  }

  Future<String> urlComprobante(String ruta) =>
      FirebaseStorage.instance.ref(ruta).getDownloadURL();

  Future<void> resolverPago(
    Pago pago, {
    required bool aprobado,
    required AppUser quien,
    String? motivo,
  }) =>
      Refs.pagos.doc(pago.id).update({
        'estado': (aprobado ? EstadoPago.pagado : EstadoPago.rechazado).wire,
        'motivoRechazo': aprobado ? null : motivo?.trim(),
        'resueltoEn': FieldValue.serverTimestamp(),
        'resueltoPor': quien.uid,
        'resueltoPorNombre': quien.nombreVisible,
      });

  /// Cobro en efectivo o conciliado fuera de la app.
  Future<void> registrarCobroManual(Pago pago, AppUser quien) =>
      Refs.pagos.doc(pago.id).update({
        'estado': EstadoPago.pagado.wire,
        'registradoAMano': true,
        'motivoRechazo': null,
        'resueltoEn': FieldValue.serverTimestamp(),
        'resueltoPor': quien.uid,
        'resueltoPorNombre': quien.nombreVisible,
      });

  Future<void> reabrirPago(Pago pago) => Refs.pagos.doc(pago.id).update({
        'estado': EstadoPago.pendiente.wire,
        'registradoAMano': false,
        'resueltoEn': null,
      });

  // -------------------------------------------------------------- ajustes

  Stream<AjustesClub> watchAjustes() =>
      Refs.ajustesClub().snapshots().map(AjustesClub.fromDoc);

  Future<void> guardarAjustes({
    required List<CuentaBancaria> cuentas,
    required String instrucciones,
  }) =>
      Refs.ajustesClub().set({
        'cuentas': [for (final c in cuentas) c.toMap()],
        'instrucciones': instrucciones.trim(),
      });

  // ----------------------------------------------------------------- chat

  Stream<List<Conversacion>> watchConversaciones(String uid) => Refs
      .conversaciones
      .where('participantes', arrayContains: uid)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Conversacion.fromDoc)
        ..sort((a, b) {
          // Avisos siempre arriba; el resto por último mensaje.
          if (a.tipo == TipoConversacion.avisos) return -1;
          if (b.tipo == TipoConversacion.avisos) return 1;
          final fa = a.ultimoMensajeEn ?? DateTime(2000);
          final fb = b.ultimoMensajeEn ?? DateTime(2000);
          return fb.compareTo(fa);
        }));

  Stream<int> watchSinLeer(String uid) => watchConversaciones(uid)
      .map((cs) => cs.fold(0, (acc, c) => acc + c.sinLeerPara(uid)));

  Stream<Conversacion?> watchConversacion(String id) => Refs.conversacion(id)
      .snapshots()
      .map((d) => d.exists ? Conversacion.fromDoc(d) : null);

  Stream<List<Mensaje>> watchMensajes(String conversacionId) => Refs
      .mensajes(conversacionId)
      .orderBy('creadoEn', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => mapearDocs(s.docs, Mensaje.fromDoc));

  /// Personas a las que se puede escribir. Una familia sólo ve al club: la
  /// consulta lo filtra porque las reglas rechazarían cualquier otra.
  Stream<List<EntradaDirectorio>> watchDirectorio(AppUser yo) {
    Query<Json> q = Refs.directorio;
    if (yo.role.isFamilia) {
      q = q.where('rol', whereIn: ['staff', 'direccion']);
    }
    return q.snapshots().map((s) => mapearDocs(s.docs, EntradaDirectorio.fromDoc)
        .where((e) => e.uid != yo.uid)
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre)));
  }

  Future<EntradaDirectorio?> entradaDirectorio(String uid) async {
    final d = await Refs.directorio.doc(uid).get();
    return d.exists ? EntradaDirectorio.fromDoc(d) : null;
  }

  /// Envía un mensaje. Si es el primero de una conversación directa, la crea
  /// en la misma operación. El último mensaje y los "sin leer" los actualiza
  /// el servidor (`alCrearMensaje`), no la app.
  Future<void> enviarMensaje({
    required String conversacionId,
    required AppUser autor,
    required String texto,
    EntradaDirectorio? directaCon,
    bool conversacionExiste = true,
  }) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    final batch = Refs.db.batch();

    // `conversacionExiste` lo aporta la pantalla (ya escucha el documento):
    // consultarlo aquí con un `get` obligaba a esperar al servidor antes de
    // enviar y, con mala cobertura, el envío se quedaba "pensando".
    if (directaCon != null) {
      if (!conversacionExiste) {
        final participantes = [autor.uid, directaCon.uid]..sort();
        batch.set(Refs.conversacion(conversacionId), {
          'tipo': TipoConversacion.directa.wire,
          'participantes': participantes,
          'nombres': {
            autor.uid: autor.nombreVisible,
            directaCon.uid: directaCon.nombre,
          },
          'sinLeer': <String, int>{},
          'creadaEn': FieldValue.serverTimestamp(),
        });
      }
    }

    final recortado = limpio.length > Mensaje.maxCaracteres
        ? limpio.substring(0, Mensaje.maxCaracteres)
        : limpio;
    batch.set(Refs.mensajes(conversacionId).doc(), {
      'texto': recortado,
      'autorUid': autor.uid,
      'autorNombre': autor.nombreVisible,
      'autorRol': autor.role.wire,
      'creadoEn': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> marcarLeida(String conversacionId, String uid) async {
    try {
      await Refs.conversacion(conversacionId).update({'sinLeer.$uid': 0});
    } catch (_) {
      // La conversación puede no existir todavía: nada que marcar.
    }
  }

  Future<void> ocultarMensaje(String conversacionId, String mensajeId) =>
      Refs.mensajes(conversacionId).doc(mensajeId).update({'oculto': true});

  // ------------------------------------------------------- equipo (staff)

  /// Dirección: cuentas del club.
  Stream<List<AppUser>> watchCuentasDelClub() => Refs.users
      .where('role', whereIn: ['staff', 'direccion'])
      .snapshots()
      .map((s) => mapearDocs(s.docs, AppUser.fromDoc)
        ..sort((a, b) => a.nombreVisible.compareTo(b.nombreVisible)));

  Future<void> asignarGrupos(String uid, List<String> grupos) =>
      Refs.user(uid).update({'grupos': grupos});

  /// Dirección: cambia nombre, rol y grupos de una cuenta del club.
  Future<void> actualizarCuentaClub(
    String uid, {
    required String nombre,
    required UserRole rol,
    required List<String> grupos,
  }) =>
      Refs.user(uid).update({
        'displayName': nombre.trim(),
        'role': rol.wire,
        'grupos': rol.isStaff ? grupos : <String>[],
      });

  Future<void> eliminarCuentaClub(String uid) async {
    try {
      await FirebaseFunctions.instanceFor(region: ClubConfig.regionFunciones)
          .httpsCallable('eliminarCuentaClub')
          .call<Map<String, dynamic>>({'uid': uid});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No se pudo eliminar la cuenta.');
    }
  }

  /// Devuelve la nueva contraseña provisional.
  Future<String> restablecerPasswordCuentaClub(String uid) async {
    try {
      final r = await FirebaseFunctions.instanceFor(
        region: ClubConfig.regionFunciones,
      ).httpsCallable('restablecerPasswordCuentaClub').call<Map<String, dynamic>>({
        'uid': uid,
      });
      return (r.data['passwordProvisional'] as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No se pudo cambiar la contraseña.');
    }
  }

  /// Crea una cuenta de staff o dirección. Sólo Dirección; lo comprueba el
  /// servidor. Devuelve la contraseña provisional para entregarla en mano.
  Future<String> crearCuentaClub({
    required String email,
    required String nombre,
    required UserRole rol,
    required List<String> grupos,
  }) async {
    try {
      final r = await FirebaseFunctions.instanceFor(
        region: ClubConfig.regionFunciones,
      ).httpsCallable('crearCuentaClub').call<Map<String, dynamic>>({
        'email': email.trim(),
        'nombre': nombre.trim(),
        'rol': rol.wire,
        'grupos': grupos,
      });
      return (r.data['passwordProvisional'] as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No se pudo crear la cuenta.');
    }
  }
}

/// Una cuota por crear: alumna, importe y concepto.
class CuotaNueva {
  const CuotaNueva({
    required this.alumna,
    required this.importe,
    required this.concepto,
  });

  final Alumna alumna;
  final double importe;
  final String concepto;
}
