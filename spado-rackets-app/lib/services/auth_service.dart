import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/club_config.dart';
import '../config/textos_legales.dart';
import '../models/app_user.dart';
import 'firestore_refs.dart';

class RegistroException implements Exception {
  const RegistroException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sesión: usuario de Auth + su documento `users/{uid}`, escuchado una vez y
/// disponible en toda la app.
class SessionController extends ChangeNotifier {
  SessionController({FirebaseAuth? auth}) : _sinFirebase = false {
    _auth = auth ?? FirebaseAuth.instance;
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Sesión resuelta sin Firebase, para dibujar pantallas en las pruebas.
  @visibleForTesting
  SessionController.paraPruebas(AppUser usuario)
      : _sinFirebase = true,
        _appUser = usuario,
        _loading = false;

  final bool _sinFirebase;
  late final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Json>>? _userDocSub;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _loading = true;

  bool get loading => _loading;
  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isSignedIn =>
      _sinFirebase ? _appUser != null : _firebaseUser != null;

  void _onAuthStateChanged(User? user) {
    _firebaseUser = user;
    _userDocSub?.cancel();
    _userDocSub = null;

    if (user == null) {
      _appUser = null;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    _userDocSub = Refs.user(user.uid).snapshots().listen(
      (doc) {
        _appUser = doc.exists ? AppUser.fromDoc(doc) : null;
        _loading = false;
        notifyListeners();
      },
      onError: (Object _) {
        _appUser = null;
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> cambiarPassword({
    required String actual,
    required String nueva,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const RegistroException('No hay ninguna sesión activa.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: actual),
      );
      await user.updatePassword(nueva);
    } on FirebaseAuthException catch (e) {
      throw RegistroException(mensajeAuth(e));
    }
  }

  /// Alta de una familia con el código que le dio el club.
  ///
  /// El orden lo imponen las reglas: cuenta de Auth → `users/{uid}` como
  /// familia y sin grupos → el SERVIDOR comprueba el código y vincula a la
  /// alumna. Si algo falla tras crear la cuenta, se borra para no dejar un
  /// usuario huérfano que no pueda volver a registrarse con ese correo.
  Future<void> registrarFamilia({
    required String email,
    required String password,
    required String codigo,
    required String nombre,
    String? telefono,
  }) async {
    final codigoLimpio = codigo.trim().toUpperCase();
    if (codigoLimpio.isEmpty) {
      throw const RegistroException('Introduce el código que te dio el club.');
    }

    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw RegistroException(mensajeAuth(e));
    }
    final uid = cred.user!.uid;

    try {
      final nuevo = AppUser(
        uid: uid,
        email: email.trim(),
        role: UserRole.familia,
        displayName: nombre.trim(),
        phone: (telefono?.trim().isEmpty ?? true) ? null : telefono!.trim(),
      );
      await Refs.user(uid).set({
        ...nuevo.toCreateMap(),
        // Constancia del consentimiento: cuándo y con qué versión del texto.
        'consentimientoEn': FieldValue.serverTimestamp(),
        'consentimientoVersion': TextosLegales.version,
        // Declaración de que es madre, padre o tutor legal de las alumnas.
        'consentimientoMenores': true,
      });
      await vincular(codigoLimpio);
    } catch (error) {
      try {
        await cred.user?.delete();
      } on FirebaseAuthException catch (_) {
        // Si no se puede borrar, el mensaje de abajo sigue siendo claro.
      }
      if (error is RegistroException) rethrow;
      throw const RegistroException(
        'No se pudo completar el registro. Inténtalo de nuevo.',
      );
    }
  }

  /// Vincula una alumna a la cuenta con su código. Devuelve su nombre.
  ///
  /// Sirve también para una familia con dos hijas: un código por alumna.
  Future<String> vincular(String codigo) async {
    try {
      final r = await FirebaseFunctions.instanceFor(
        region: ClubConfig.regionFunciones,
      ).httpsCallable('vincularAlumna').call<Map<String, dynamic>>({
        'codigo': codigo.trim().toUpperCase(),
      });
      return (r.data['nombre'] as String?) ?? 'La alumna';
    } on FirebaseFunctionsException catch (e) {
      throw RegistroException(
        (e.message?.trim().isNotEmpty ?? false)
            ? e.message!.trim()
            : 'No se pudo vincular. Inténtalo de nuevo.',
      );
    }
  }

  static String mensajeAuth(FirebaseAuthException error) => switch (error.code) {
        'invalid-email' => 'El email no tiene un formato válido.',
        'user-disabled' => 'Esta cuenta está desactivada. Contacta con el club.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email o contraseña incorrectos.',
        'email-already-in-use' => 'Ya existe una cuenta con este email.',
        'weak-password' => 'La contraseña debe tener al menos 8 caracteres.',
        'too-many-requests' =>
          'Demasiados intentos. Espera unos minutos y vuelve a probar.',
        'network-request-failed' =>
          'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
        'requires-recent-login' =>
          'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.',
        _ => 'No se pudo completar la operación (${error.code}).',
      };

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
