import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/app_shell.dart';
import '../screens/auth/activar_cuenta_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registro_screen.dart';
import '../screens/chat/conversacion_screen.dart';
import '../screens/chat/nueva_conversacion_screen.dart';
import '../screens/direccion/alumnas_screen.dart';
import '../screens/direccion/asistencia_resumen_screen.dart';
import '../screens/direccion/datos_bancarios_screen.dart';
import '../screens/direccion/equipo_screen.dart';
import '../screens/direccion/nueva_cuota_screen.dart';
import '../screens/direccion/familias_screen.dart';
import '../screens/direccion/grupos_screen.dart';
import '../screens/direccion/informes_screen.dart';
import '../screens/shared/documentos_screen.dart';
import '../screens/staff/pasar_lista_screen.dart';
import '../models/pago.dart';
import '../services/auth_service.dart';

GoRouter buildRouter(SessionController session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      if (session.loading) return null;
      final path = state.matchedLocation;
      final enAuth =
          path == '/login' || path == '/registro' || path == '/activar';
      // Los textos legales se leen sin cuenta, antes de registrarse.
      final legal = path == '/privacidad' || path == '/terminos';
      if (!session.isSignedIn && !enAuth && !legal) return '/login';
      if (session.isSignedIn && enAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AppShell()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/activar', builder: (_, __) => const ActivarCuentaScreen()),
      GoRoute(path: '/registro', builder: (_, __) => const RegistroScreen()),
      GoRoute(
        path: '/privacidad',
        builder: (_, __) => DocumentosScreen.privacidad(),
      ),
      GoRoute(
        path: '/terminos',
        builder: (_, __) => DocumentosScreen.terminos(),
      ),
      GoRoute(
        path: '/lista',
        builder: (_, s) => PasarListaScreen(
          fecha: s.uri.queryParameters['fecha'],
        ),
      ),
      GoRoute(
        path: '/chat/nueva',
        builder: (_, __) => const NuevaConversacionScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) =>
            ConversacionScreen(conversacionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/asistencia',
        builder: (_, __) => const AsistenciaResumenScreen(),
      ),
      GoRoute(
        path: '/cuotas/nueva',
        builder: (_, s) => NuevaCuotaScreen(
          periodo: s.uri.queryParameters['periodo'] ?? periodoDe(DateTime.now()),
        ),
      ),
      GoRoute(path: '/familias', builder: (_, __) => const FamiliasScreen()),
      GoRoute(path: '/informes', builder: (_, __) => const InformesScreen()),
      GoRoute(path: '/alumnas', builder: (_, __) => const AlumnasScreen()),
      GoRoute(path: '/grupos', builder: (_, __) => const GruposScreen()),
      GoRoute(path: '/equipo', builder: (_, __) => const EquipoScreen()),
      GoRoute(
        path: '/datos-bancarios',
        builder: (_, __) => const DatosBancariosScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Volver al inicio'),
        ),
      ),
    ),
  );
}
