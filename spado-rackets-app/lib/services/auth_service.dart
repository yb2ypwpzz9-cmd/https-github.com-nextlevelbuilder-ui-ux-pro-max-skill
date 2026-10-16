import 'dart:async';
import 'dart:convert';

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
        _vincularPendiente();
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
        // Se vincula sola en cuanto la familia verifique su correo, aunque
        // cierre la app o lo haga desde otro dispositivo.
        'codigoPendiente': codigoLimpio,
      });
      // El servidor solo vincula con el correo verificado: se envía el enlace
      // y el código queda en memoria hasta que la familia lo confirme.
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {
        // Se puede reenviar desde la pantalla de verificación.
      }
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

  /// Todos los datos personales de la cuenta, como texto JSON (derecho de
  /// acceso y portabilidad).
  Future<String> exportarMisDatos() async {
    try {
      final r = await FirebaseFunctions.instanceFor(
        region: ClubConfig.regionFunciones,
      ).httpsCallable('exportarMisDatos').call<Map<Object?, Object?>>();
      return const JsonEncoder.withIndent('  ').convert(r.data);
    } on FirebaseFunctionsException catch (e) {
      throw RegistroException(e.message ?? 'No se pudieron preparar tus datos.');
    }
  }

  /// Elimina la cuenta y sus datos personales (derecho de supresión). Pide la
  /// contraseña de nuevo: es una acción que no se puede deshacer.
  Future<void> eliminarMiCuenta(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const RegistroException('No hay ninguna sesión activa.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await user.getIdToken(true);
      await FirebaseFunctions.instanceFor(region: ClubConfig.regionFunciones)
          .httpsCallable('eliminarMiCuenta')
          .call<Map<String, dynamic>>();
    } on FirebaseAuthException catch (e) {
      throw RegistroException(mensajeAuth(e));
    } on FirebaseFunctionsException catch (e) {
      throw RegistroException(e.message ?? 'No se pudo eliminar la cuenta.');
    }
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Primer acceso del equipo: correo + código de activación + contraseña
  /// propia. Después inicia sesión con ella.
  Future<void> activarCuenta({
    required String email,
    required String codigo,
    required String password,
  }) async {
    try {
      await FirebaseFunctions.instanceFor(region: ClubConfig.regionFunciones)
          .httpsCallable('activarCuenta')
          .call<Map<String, dynamic>>({
        'email': email.trim(),
        'codigo': codigo.trim(),
        'password': password,
      });
    } on FirebaseFunctionsException catch (e) {
      throw RegistroException(
        (e.message?.trim().isNotEmpty ?? false)
            ? e.message!.trim()
            : 'No se pudo activar la cuenta.',
      );
    }
    await signIn(email: email, password: password);
  }

  /// Cambio de la contraseña provisional que entregó Dirección.
  Future<void> cambiarPasswordObligatorio({
    required String actual,
    required String nueva,
  }) async {
    await cambiarPassword(actual: actual, nueva: nueva);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await Refs.user(uid).update({'debeCambiarPassword': false});
    }
  }

  /// Constancia de que el staff ha leído el aviso sobre el fichaje.
  Future<void> aceptarAvisoUbicacion() {
    final uid = _auth.currentUser!.uid;
    return Refs.user(uid).update({
      'avisoUbicacionVersion': TextosLegales.avisoStaffVersion,
      'avisoUbicacionEn': FieldValue.serverTimestamp(),
    });
  }

  bool _vinculando = false;

  /// Motivo por el que no se pudo vincular a la alumna del registro.
  String? errorVinculacion;

  /// Si hay un código pendiente y el correo ya está verificado, vincula a la
  /// alumna. Se llama al cargar el perfil y al confirmar la verificación.
  Future<void> _vincularPendiente() async {
    final usuario = _appUser;
    final codigo = usuario?.codigoPendiente;
    if (_vinculando || codigo == null || usuario!.role != UserRole.familia) {
      return;
    }
    _vinculando = true;
    try {
      await _auth.currentUser?.reload();
      final actual = _auth.currentUser;
      if (actual == null || !actual.emailVerified) return;
      _firebaseUser = actual;
      errorVinculacion = null;
      await vincular(codigo);
    } on RegistroException catch (e) {
      errorVinculacion = e.message;
      // El código no sirve: se quita para no reintentarlo en bucle.
      try {
        await Refs.user(usuario.uid).update({'codigoPendiente': FieldValue.delete()});
      } catch (_) {}
    } catch (_) {
      // Sin conexión u otro fallo pasajero: se reintentará al volver a abrir.
    } finally {
      _vinculando = false;
      notifyListeners();
    }
  }

  /// Una familia con la cuenta creada pero sin el correo verificado.
  bool get necesitaVerificarCorreo =>
      !_sinFirebase &&
      _firebaseUser != null &&
      !_firebaseUser!.emailVerified &&
      _appUser?.role == UserRole.familia;

  Future<void> reenviarVerificacion() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw RegistroException(mensajeAuth(e));
    }
  }

  /// Vuelve a consultar si ya verificó el correo. Si es así y quedó un código
  /// pendiente del registro, vincula a la alumna. Devuelve `true` si ya está
  /// verificado.
  Future<bool> comprobarVerificacion() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final actual = _auth.currentUser;
    if (actual == null || !actual.emailVerified) return false;
    await actual.getIdToken(true);
    _firebaseUser = actual;
    notifyListeners();
    await _vincularPendiente();
    return true;
  }

  /// Vincula una alumna a la cuenta con su código. Devuelve su nombre.
  ///
  /// Sirve también para una familia con dos hijas: un código por alumna.
  Future<String> vincular(String codigo) async {
    try {
      // El servidor mira `email_verified` en el token: se renueva antes.
      await _auth.currentUser?.getIdToken(true);
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
