// Configuración del proyecto de Firebase de Spado Rackets.
//
// Proyecto `spado-rackets` (separado del de Spado Soccer).
//
// Estos valores NO son secretos: van dentro de cualquier web que use Firebase.
// Lo que protege los datos son las reglas (firestore.rules y storage.rules).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAeGfQbsUsFAqJ8v7LkEcUqAkHcT4fg_WE',
    appId: '1:928554561378:web:b44544610fe04fcf37463b',
    messagingSenderId: '928554561378',
    projectId: 'spado-rackets',
    authDomain: 'spado-rackets.firebaseapp.com',
    storageBucket: 'spado-rackets.firebasestorage.app',
  );

  /// Proyecto ficticio para los emuladores locales (el prefijo `demo-` hace
  /// que Firebase no intente conectar con ningún proyecto real).
  static const FirebaseOptions emulador = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-spado-rackets',
    authDomain: 'demo-spado-rackets.firebaseapp.com',
    storageBucket: 'demo-spado-rackets.appspot.com',
  );

  /// Si alguien vuelve a dejar la plantilla sin rellenar, la app lo dice al
  /// arrancar en vez de fallar con un error ilegible de Firebase.
  static bool get configurado => web.projectId != 'PENDIENTE';
}
