import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef Json = Map<String, dynamic>;
typedef JsonCollection = CollectionReference<Json>;
typedef JsonDoc = DocumentReference<Json>;

/// Nombres de las colecciones en un único sitio.
///
/// Esquema completo en `docs/esquema.md`. Resumen:
///
///   users/{uid}               perfil y rol (lo lee el propio usuario y Dirección)
///   directorio/{uid}          nombre y rol, para el chat (lo escribe el servidor)
///   grupos/{id}               grupos de entrenamiento y su cuota
///   alumnas/{id}              ficha de cada alumna
///   codigosVinculacion/{id}   código que da el club a cada familia
///   jornadas/{id}             fichaje de entrada y salida del staff
///   asistencias/{id}          pase de lista: `{grupo}_{fecha}_{alumna}`
///   ausencias/{id}            faltas avisadas por la familia
///   pagos/{id}                cuotas: `{alumna}_{yyyy-MM}`
///   ajustes/club              cuentas bancarias del club
///   conversaciones/{id}       chat; mensajes en la subcolección `mensajes`
abstract final class Refs {
  static FirebaseFirestore? _instancia;

  static FirebaseFirestore get db => _instancia ?? FirebaseFirestore.instance;

  /// Sólo para pruebas contra una base de datos falsa.
  @visibleForTesting
  static void usarInstancia(FirebaseFirestore? instancia) =>
      _instancia = instancia;

  static JsonCollection get users => db.collection('users');
  static JsonCollection get directorio => db.collection('directorio');
  static JsonCollection get grupos => db.collection('grupos');
  static JsonCollection get alumnas => db.collection('alumnas');
  static JsonCollection get codigos => db.collection('codigosVinculacion');
  static JsonCollection get jornadas => db.collection('jornadas');
  static JsonCollection get asistencias => db.collection('asistencias');
  static JsonCollection get ausencias => db.collection('ausencias');
  static JsonCollection get pagos => db.collection('pagos');
  static JsonCollection get conversaciones => db.collection('conversaciones');

  static JsonDoc user(String uid) => users.doc(uid);
  static JsonDoc ajustesClub() => db.collection('ajustes').doc('club');
  static JsonDoc conversacion(String id) => conversaciones.doc(id);
  static JsonCollection mensajes(String conversacionId) =>
      conversacion(conversacionId).collection('mensajes');
}

/// Convierte documentos descartando los que no se puedan leer: un documento
/// roto no debe dejar en blanco una pantalla entera.
List<T> mapearDocs<T>(
  Iterable<DocumentSnapshot<Json>> docs,
  T Function(DocumentSnapshot<Json>) construir,
) {
  final resultado = <T>[];
  for (final doc in docs) {
    try {
      resultado.add(construir(doc));
    } catch (_) {
      // Documento ilegible: se omite.
    }
  }
  return resultado;
}

/// Lista de textos tolerante con datos mal formados.
List<String> listaDeTextos(Object? raw) => switch (raw) {
      final List<dynamic> list =>
        list.whereType<String>().where((s) => s.isNotEmpty).toList(),
      final String single when single.isNotEmpty => [single],
      _ => const <String>[],
    };

DateTime? fechaDe(Object? raw) => raw is Timestamp ? raw.toDate() : null;
