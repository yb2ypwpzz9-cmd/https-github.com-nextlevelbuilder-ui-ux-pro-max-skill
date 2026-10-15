import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';
import 'app_user.dart';

/// Tipo de conversación.
enum TipoConversacion {
  /// Canal de avisos del club: publican Dirección y staff, el resto lee.
  avisos,

  /// El chat de un grupo: familias del grupo, su entrenador y Dirección.
  grupo,

  /// Entre dos personas. Una familia sólo puede abrir una con el club, nunca
  /// con otra familia.
  directa;

  static TipoConversacion fromString(String? v) => switch (v) {
        'avisos' => TipoConversacion.avisos,
        'grupo' => TipoConversacion.grupo,
        _ => TipoConversacion.directa,
      };

  String get wire => name;
}

/// Documento `conversaciones/{id}`.
///
/// Ids deterministas, y en eso descansa media seguridad del chat:
///   · `avisos`             el canal de avisos (uno solo)
///   · `g_{grupoId}`        el chat de un grupo
///   · `d_{uidA}_{uidB}`    directa, uids ordenados
///
/// `participantes` de avisos y grupos lo mantiene el servidor. Así la app
/// pide todas sus conversaciones con una sola consulta (`array-contains` su
/// uid) y las reglas deciden quién lee con el mismo campo.
class Conversacion {
  const Conversacion({
    required this.id,
    required this.tipo,
    this.participantes = const [],
    this.nombres = const {},
    this.titulo = '',
    this.grupo = '',
    this.ultimoMensaje = '',
    this.ultimoAutor = '',
    this.ultimoMensajeEn,
    this.sinLeer = const {},
  });

  final String id;
  final TipoConversacion tipo;
  final List<String> participantes;
  final Map<String, String> nombres;
  final String titulo;
  final String grupo;
  final String ultimoMensaje;
  final String ultimoAutor;
  final DateTime? ultimoMensajeEn;
  final Map<String, int> sinLeer;

  static const idAvisos = 'avisos';
  static String idGrupo(String grupoId) => 'g_$grupoId';
  static String idDirecta(String a, String b) {
    final o = [a, b]..sort();
    return 'd_${o[0]}_${o[1]}';
  }

  int sinLeerPara(String uid) => sinLeer[uid] ?? 0;

  String otro(String miUid) =>
      participantes.firstWhere((p) => p != miUid, orElse: () => '');

  /// Sólo Dirección y staff publican en avisos.
  bool puedeEscribir(UserRole rol) =>
      tipo != TipoConversacion.avisos || rol.esDelClub;

  String nombrePara(String miUid) {
    if (tipo == TipoConversacion.avisos) return 'Avisos del club';
    if (titulo.trim().isNotEmpty) return titulo.trim();
    final n = nombres[otro(miUid)]?.trim() ?? '';
    return n.isEmpty ? 'Conversación' : n;
  }

  factory Conversacion.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Conversacion(
      id: doc.id,
      tipo: TipoConversacion.fromString(data['tipo'] as String?),
      participantes: listaDeTextos(data['participantes']),
      nombres: {
        for (final e
            in (data['nombres'] as Map<dynamic, dynamic>? ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      titulo: (data['titulo'] as String?) ?? '',
      grupo: (data['grupo'] as String?) ?? '',
      ultimoMensaje: (data['ultimoMensaje'] as String?) ?? '',
      ultimoAutor: (data['ultimoAutor'] as String?) ?? '',
      ultimoMensajeEn: fechaDe(data['ultimoMensajeEn']),
      sinLeer: {
        for (final e
            in (data['sinLeer'] as Map<dynamic, dynamic>? ?? const {}).entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
      },
    );
  }
}

/// Documento `conversaciones/{id}/mensajes/{id}`.
class Mensaje {
  const Mensaje({
    required this.id,
    required this.texto,
    required this.autorUid,
    required this.autorNombre,
    required this.autorRol,
    this.creadoEn,
    this.oculto = false,
  });

  final String id;
  final String texto;
  final String autorUid;
  final String autorNombre;
  final UserRole autorRol;
  final DateTime? creadoEn;

  /// Retirado por Dirección. No se borra, para poder explicar la decisión.
  final bool oculto;

  static const maxCaracteres = 2000;

  factory Mensaje.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Mensaje(
      id: doc.id,
      texto: (data['texto'] as String?) ?? '',
      autorUid: (data['autorUid'] as String?) ?? '',
      autorNombre: (data['autorNombre'] as String?) ?? 'Alguien',
      autorRol: UserRole.fromString(data['autorRol'] as String?),
      // Recién enviado, la hora del servidor aún no ha vuelto.
      creadoEn: fechaDe(data['creadoEn']) ?? DateTime.now(),
      oculto: (data['oculto'] as bool?) ?? false,
    );
  }
}

/// Documento `directorio/{uid}`: nombre y rol, nada más. Lo escribe el
/// servidor; sirve para elegir a quién escribir sin exponer `users`.
class EntradaDirectorio {
  const EntradaDirectorio({
    required this.uid,
    required this.nombre,
    required this.rol,
    this.grupos = const [],
  });

  final String uid;
  final String nombre;
  final UserRole rol;
  final List<String> grupos;

  factory EntradaDirectorio.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EntradaDirectorio(
      uid: doc.id,
      nombre: (data['nombre'] as String?)?.trim().isNotEmpty ?? false
          ? (data['nombre'] as String).trim()
          : 'Sin nombre',
      rol: UserRole.fromString(data['rol'] as String?),
      grupos: listaDeTextos(data['grupos']),
    );
  }
}
