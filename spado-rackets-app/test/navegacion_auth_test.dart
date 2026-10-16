import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spado_rackets_app/screens/auth/activar_cuenta_screen.dart';
import 'package:spado_rackets_app/screens/auth/login_screen.dart';
import 'package:spado_rackets_app/screens/auth/registro_screen.dart';

void main() {
  testWidgets('un solo toque basta para ir y volver', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/registro', builder: (_, __) => const RegistroScreen()),
        GoRoute(path: '/activar', builder: (_, __) => const ActivarCuentaScreen()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final boton = find.text('Soy del equipo: primer acceso');
    expect(boton, findsOneWidget);
    // Sin tener que desplazar la pantalla y lejos del borde inferior.
    expect(tester.getCenter(boton).dy, lessThan(844 - 90));
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.text('Activa tu cuenta'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}
