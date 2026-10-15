import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/club_config.dart';
import 'firestore_refs.dart';

/// Notificaciones push en la web.
///
/// El envío lo hacen las Cloud Functions; la app sólo guarda el token del
/// navegador en `users/{uid}.fcmTokens`.
///
/// Limitación de la web en iPhone: Safari sólo entrega push si la app se ha
/// añadido a la pantalla de inicio (Compartir → Añadir a pantalla de inicio).
/// En una pestaña normal no llegan; el contador de mensajes sí funciona.
class PushService {
  String? _uid;
  StreamSubscription<String>? _refreshSub;

  bool get disponible => ClubConfig.vapidKey.isNotEmpty;

  /// Pide permiso y registra este navegador. Se llama desde un botón: los
  /// navegadores bloquean la petición de permiso si no la inicia el usuario.
  Future<bool> activar(String uid) async {
    if (!disponible) return false;
    try {
      final ajustes = await FirebaseMessaging.instance.requestPermission();
      if (ajustes.authorizationStatus != AuthorizationStatus.authorized &&
          ajustes.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }
      await registrar(uid);
      return true;
    } catch (e) {
      debugPrint('Push no disponible: $e');
      return false;
    }
  }

  /// Si el permiso ya estaba concedido, refresca el token sin preguntar.
  Future<void> registrar(String uid) async {
    if (!disponible || _uid == uid) return;
    try {
      final ajustes =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (ajustes.authorizationStatus != AuthorizationStatus.authorized) return;
      _uid = uid;
      final token = await FirebaseMessaging.instance
          .getToken(vapidKey: ClubConfig.vapidKey);
      if (token != null) await _guardar(uid, token);
      await _refreshSub?.cancel();
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => _guardar(uid, t));
    } catch (e) {
      debugPrint('Push no disponible: $e');
    }
  }

  /// Al cerrar sesión se quita el token: si no, el siguiente usuario de este
  /// navegador recibiría los avisos del anterior.
  Future<void> desregistrar() async {
    final uid = _uid;
    _uid = null;
    await _refreshSub?.cancel();
    if (uid == null || !disponible) return;
    try {
      final token = await FirebaseMessaging.instance
          .getToken(vapidKey: ClubConfig.vapidKey);
      if (token != null) {
        await Refs.user(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (_) {
      // Sin permisos tras cerrar sesión: no es relevante.
    }
  }

  Future<void> _guardar(String uid, String token) async {
    try {
      await Refs.user(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (_) {
      // Este navegador no recibirá push; la app sigue funcionando.
    }
  }
}
