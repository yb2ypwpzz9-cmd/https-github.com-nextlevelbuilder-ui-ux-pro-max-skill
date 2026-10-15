// Configuración del proyecto de Firebase de Spado Rackets.
//
// PLANTILLA. Se rellena una sola vez de cualquiera de estas dos formas:
//
//   a) Automática (recomendada):
//        dart pub global activate flutterfire_cli
//        flutterfire configure --project=<id-del-proyecto> --platforms=web
//      Sobrescribe este archivo entero.
//
//   b) A mano: consola de Firebase → Configuración del proyecto → Tus apps →
//      app web → "Configuración del SDK" y copiar aquí los valores.
//
// Estos valores NO son secretos: van dentro de cualquier web que use Firebase.
// Lo que protege los datos son las reglas (firestore.rules y storage.rules).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PENDIENTE',
    appId: 'PENDIENTE',
    messagingSenderId: 'PENDIENTE',
    projectId: 'PENDIENTE',
    authDomain: 'PENDIENTE.firebaseapp.com',
    storageBucket: 'PENDIENTE.firebasestorage.app',
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

  /// Mientras sea la plantilla, la app lo dice al arrancar en vez de fallar
  /// con un error ilegible de Firebase.
  static bool get configurado => web.projectId != 'PENDIENTE';
}
