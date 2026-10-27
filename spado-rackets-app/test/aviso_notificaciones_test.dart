import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spado_rackets_app/models/app_user.dart';
import 'package:spado_rackets_app/services/auth_service.dart';
import 'package:spado_rackets_app/services/push_service.dart';
import 'package:spado_rackets_app/widgets/aviso_notificaciones.dart';

class _PushFalso extends PushService {
  _PushFalso(this.inicial);
  final EstadoPush inicial;
  int activaciones = 0;

  @override
  Future<EstadoPush> estado() async =>
      activaciones > 0 ? EstadoPush.activo : inicial;

  @override
  Future<bool> activar(String uid) async {
    activaciones++;
    return true;
  }
}

Future<void> montar(WidgetTester tester, PushService push) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  const usuario = AppUser(
    uid: 'u1',
    email: 'a@b.c',
    role: UserRole.familia,
    grupos: [],
  );
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<PushService>.value(value: push),
      ChangeNotifierProvider<SessionController>.value(
          value: SessionController.paraPruebas(usuario)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: Column(children: [AvisoNotificaciones()])),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un toque en "Activar avisos" pide el permiso y oculta la tarjeta',
      (tester) async {
    final push = _PushFalso(EstadoPush.pendiente);
    await montar(tester, push);
    expect(find.text('Activar avisos'), findsOneWidget);
    await tester.tap(find.text('Activar avisos'));
    await tester.pumpAndSettle();
    expect(push.activaciones, 1);
    expect(find.text('Activar avisos'), findsNothing);
  });

  testWidgets('si el navegador no admite avisos, la tarjeta explica cómo instalar',
      (tester) async {
    await montar(tester, _PushFalso(EstadoPush.noSoportado));
    expect(find.text('Cómo instalarla'), findsOneWidget);
  });
}
