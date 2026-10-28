import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El iPhone se reserva ~34 px abajo (indicador de inicio) y retrasa o cancela
/// los toques ahí. La app le dice a Flutter esa franja (MediaQuery.padding) y
/// la barra de navegación debe quedar por encima.
void main() {
  testWidgets('con la franja del sistema, las pestañas quedan por encima y responden',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    var seleccion = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: 34),
              viewPadding: mq.viewPadding.copyWith(bottom: 34),
            ),
            child: child!,
          );
        },
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: seleccion,
              onDestinationSelected: (v) => setState(() => seleccion = v),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
                NavigationDestination(icon: Icon(Icons.receipt), label: 'Pagos'),
                NavigationDestination(icon: Icon(Icons.forum), label: 'Mensajes'),
              ],
            ),
          ),
        ),
      ),
    );

    // Todas las etiquetas quedan fuera de los 34 px inferiores.
    for (final texto in ['Inicio', 'Pagos', 'Mensajes']) {
      final abajo = tester.getBottomLeft(find.text(texto)).dy;
      expect(abajo, lessThanOrEqualTo(844 - 34),
          reason: '"$texto" invade la zona de gestos de iOS');
    }

    // Y una pulsación en el centro de cada pestaña la selecciona.
    await tester.tap(find.text('Pagos'));
    await tester.pump();
    expect(seleccion, 1);
    await tester.tap(find.text('Mensajes'));
    await tester.pump();
    expect(seleccion, 2);
    await tester.tap(find.byIcon(Icons.home));
    await tester.pump();
    expect(seleccion, 0);
  });
}
