import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_refs.dart';

/// Los tres perfiles. El rol lo asigna el servidor; nunca lo decide la app.
enum UserRole {
  familia,
  staff,
  direccion;

  static UserRole fromString(String? value) => switch (value) {
        'staff' => UserRole.staff,
        'direccion' => UserRole.direccion,
        _ => UserRole.familia,
      };

  String get wire => name;

  String get label => switch (this) {
        UserRole.familia => 'Familia',
        UserRole.staff => 'Staff',
        UserRole.direccion => 'Dirección',
      };

  bool get isFamilia => this == UserRole.familia;
  bool get isStaff => this == UserRole.staff;
  bool get isDireccion => this == UserRole.direccion;
  bool get esDelClub => isStaff || isDireccion;
}

/// Documento `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.grupos = const [],
    this.displayName,
    this.phone,
    this.debeCambiarPassword = false,
    this.avisoUbicacionVersion,
    this.codigoPendiente,
    this.todosLosGrupos = false,
  });

  final String uid;
  final String email;
  final UserRole role;

  /// Grupos a los que pertenece. En el staff los asigna Dirección; en las
  /// familias los calcula el servidor a partir de sus alumnas. Deciden a qué
  /// datos se llega, así que la app nunca los escribe en su propio usuario.
  final List<String> grupos;

  final String? displayName;
  final String? phone;

  /// Cuenta creada por Dirección con contraseña provisional: hay que cambiarla.
  final bool debeCambiarPassword;

  /// Versión del aviso de ubicación que el staff ha aceptado.
  final String? avisoUbicacionVersion;

  /// Código de la alumna dado en el registro, a la espera de que la familia
  /// verifique su correo para vincularla.
  final String? codigoPendiente;

  /// Staff con acceso a todos los grupos, también a los que se creen luego.
  final bool todosLosGrupos;

  factory AppUser.fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      role: UserRole.fromString(data['role'] as String?),
      grupos: listaDeTextos(data['grupos']),
      displayName: data['displayName'] as String?,
      phone: data['phone'] as String?,
      debeCambiarPassword: (data['debeCambiarPassword'] as bool?) ?? false,
      avisoUbicacionVersion: data['avisoUbicacionVersion'] as String?,
      todosLosGrupos: (data['todosLosGrupos'] as bool?) ?? false,
      codigoPendiente: (data['codigoPendiente'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['codigoPendiente'] as String).trim(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'uid': uid,
        'email': email,
        'role': role.wire,
        'grupos': grupos,
        if (displayName != null) 'displayName': displayName,
        if (phone != null) 'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      };

  String get nombreVisible {
    final nombre = displayName?.trim() ?? '';
    if (nombre.isNotEmpty) return nombre;
    return email.contains('@') ? email.split('@').first : 'Sin nombre';
  }

  String get iniciales => inicialesDe(nombreVisible);
}

String inicialesDe(String nombre) {
  final partes = nombre
      .replaceFirst(RegExp(r'^Familia\s+', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}
