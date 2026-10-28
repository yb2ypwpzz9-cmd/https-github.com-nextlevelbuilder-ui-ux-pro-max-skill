import 'package:flutter_test/flutter_test.dart';
import 'package:spado_rackets_app/models/alumna.dart';
import 'package:spado_rackets_app/models/cambio_clase.dart';

void main() {
  const lucia = Alumna(
    id: 'a1',
    nombre: 'Lucía',
    grupo: 'general',
    dias: [1, 3],
    horaInicio: '17:00',
    horarios: {1: '17:00', 3: '18:30'},
  );
  final lunes = DateTime(2026, 11, 2); // lunes
  final miercoles = DateTime(2026, 11, 4);
  final martes = DateTime(2026, 11, 3);

  test('cada día de clase tiene su hora', () {
    expect(lucia.horaDelDia(1), '17:00');
    expect(lucia.horaDelDia(3), '18:30');
    expect(claseDelDia(lucia, lunes, null)?.hora, '17:00');
    expect(claseDelDia(lucia, miercoles, null)?.hora, '18:30');
    expect(claseDelDia(lucia, martes, null), isNull);
  });

  test('el texto del horario enseña la hora de cada día si difieren', () {
    expect(lucia.horasDistintas, isTrue);
    expect(lucia.horarioTexto, 'Lun 5:00 PM · Mié 6:30 PM');
  });

  test('una ficha de antes, sin horas por día, usa la hora única', () {
    const antigua = Alumna(
      id: 'a2',
      nombre: 'Sofía',
      grupo: 'general',
      dias: [2, 4],
      horaInicio: '17:30',
    );
    expect(antigua.horaDelDia(4), '17:30');
    expect(antigua.horasDistintas, isFalse);
    expect(antigua.horarioTexto, 'Mar · Jue · 5:30 PM');
  });

  test('un cambio puntual con otra hora manda sobre la hora del día', () {
    const cambio = CambioClase(
      id: 'a1_2026-11-04',
      alumnaId: 'a1',
      grupo: 'general',
      fecha: '2026-11-04',
      tipo: TipoCambio.extra,
      horaInicio: '19:00',
    );
    expect(claseDelDia(lucia, miercoles, cambio)?.hora, '19:00');
  });
}
