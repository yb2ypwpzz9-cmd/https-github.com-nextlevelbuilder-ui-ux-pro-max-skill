import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'config/club_config.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'services/auth_service.dart';
import 'services/club_repository.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'widgets/club_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  if (!_usarEmulador && !DefaultFirebaseOptions.configurado) {
    runApp(const PantallaDeArranqueRoto(
      motivo: 'Falta conectar la app con su proyecto de Firebase '
          '(lib/firebase_options.dart). Ver README, paso 1.',
    ));
    return;
  }

  // Sólo se espera a Firebase, con límite de tiempo: con mala red, una espera
  // sin fin deja la pantalla en blanco sin explicación.
  try {
    await Firebase.initializeApp(
      options: _usarEmulador
          ? DefaultFirebaseOptions.emulador
          : DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    if (_usarEmulador) await _conectarEmuladores();
  } on TimeoutException {
    runApp(const PantallaDeArranqueRoto(
      motivo: 'No se pudo contactar con el servidor del club.',
    ));
    return;
  } catch (error) {
    runApp(PantallaDeArranqueRoto(motivo: '$error'));
    return;
  }

  // Caché local: segunda visita instantánea y la app sigue funcionando con
  // mala cobertura en la pista. En ventana privada no se puede activar, y eso
  // no puede tumbar el arranque.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      // Redes móviles, wifis de hotel/club y algunos operadores bloquean el
      // canal de streaming de Firestore y la app se queda cargando para
      // siempre: con esto detecta el bloqueo y cambia sola a long-polling.
      webExperimentalAutoDetectLongPolling: true,
    );
  } catch (_) {}

  runApp(SpadoRacketsApp(pushService: PushService()..refrescarEstado()));
}

/// `flutter run -d chrome --dart-define=EMULADOR=true` trabaja contra los
/// emuladores locales de Firebase (`firebase emulators:start`) sin tocar los
/// datos reales.
const _usarEmulador = bool.fromEnvironment('EMULADOR');

Future<void> _conectarEmuladores() async {
  const host = 'localhost';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  FirebaseFunctions.instanceFor(region: ClubConfig.regionFunciones)
      .useFunctionsEmulator(host, 5001);
}

class SpadoRacketsApp extends StatefulWidget {
  const SpadoRacketsApp({super.key, required this.pushService});
  final PushService pushService;

  @override
  State<SpadoRacketsApp> createState() => _SpadoRacketsAppState();
}

class _SpadoRacketsAppState extends State<SpadoRacketsApp> {
  late final SessionController _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _session = SessionController();
    // Una sola vez: reconstruirlo en cada build perdería la navegación.
    _router = buildRouter(_session);
    _session.addListener(_sincronizarPush);
  }

  void _sincronizarPush() {
    final uid = _session.appUser?.uid;
    if (uid != null) widget.pushService.registrar(uid);
  }

  @override
  void dispose() {
    _session.removeListener(_sincronizarPush);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: _session),
        Provider<PushService>.value(value: widget.pushService),
        Provider<ClubRepository>.value(value: const ClubRepository()),
      ],
      child: MaterialApp.router(
        title: 'Spado Rackets',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

/// Lo que se ve si la app no puede ni arrancar: mejor un mensaje que una
/// pantalla en blanco.
class PantallaDeArranqueRoto extends StatelessWidget {
  const PantallaDeArranqueRoto({super.key, required this.motivo});
  final String motivo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.navyDeep,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ClubLogo(height: 90, blanco: true),
                const SizedBox(height: 28),
                const Text(
                  'No se pudo iniciar la aplicación',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Comprueba tu conexión y vuelve a intentarlo. Si sigue sin '
                  'funcionar, avisa al club.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 18),
                Text(
                  motivo,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
