import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spado_rackets_app/theme/app_theme.dart';

/// Un dedo que se queda medio segundo en una pestaña no debe perder el toque:
/// los tooltips de pulsación larga lo cancelaban.
void main() {
  testWidgets('mantener el dedo 700 ms sobre una pestaña la selecciona igualmente',
      (tester) async {
    var seleccion = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(tooltipTheme: AppTheme.light().tooltipTheme),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: seleccion,
              onDestinationSelected: (v) => setState(() => seleccion = v),
              destinations: const [
                NavigationDestination(
                    tooltip: '', icon: Icon(Icons.home), label: 'Inicio'),
                NavigationDestination(
                    tooltip: '', icon: Icon(Icons.receipt), label: 'Pagos'),
              ],
            ),
          ),
        ),
      ),
    );
    final gesto = await tester.startGesture(tester.getCenter(find.text('Pagos')));
    await tester.pump(const Duration(milliseconds: 700));
    await gesto.up();
    await tester.pump();
    expect(seleccion, 1);
  });

  test('el tema no abre tooltips con pulsación larga', () {
    expect(AppTheme.light().tooltipTheme.triggerMode, TooltipTriggerMode.manual);
  });
}
