import 'package:flutter_test/flutter_test.dart';
import 'package:spado_rackets_app/models/clase_anulada.dart';

ClaseAnulada anulada(int minutos, int recuperados) => ClaseAnulada(
      id: 'a1_2026-11-09',
      alumnaId: 'a1',
      alumnaNombre: 'Lucía Pérez',
      grupo: 'general',
      familiaUid: 'f1',
      fecha: '2026-11-09',
      minutos: minutos,
      motivo: MotivoAnulacion.clima,
      recuperados: recuperados,
    );

void main() {
  test('las horas pendientes salen de lo anulado menos lo recuperado', () {
    expect(anulada(60, 0).pendientes, 60);
    expect(anulada(60, 45).pendientes, 15);
    expect(anulada(60, 60).recuperada, isTrue);
    expect(anulada(60, 90).pendientes, 0); // nunca negativo
  });

  test('duraciones legibles', () {
    expect(duracionTexto(30), '30 min');
    expect(duracionTexto(60), '1 h');
    expect(duracionTexto(90), '1 h 30');
    expect(duracionTexto(120), '2 h');
  });

  test('un motivo desconocido se queda en "otro"', () {
    expect(MotivoAnulacion.fromString('xyz'), MotivoAnulacion.otro);
    expect(MotivoAnulacion.fromString('clima'), MotivoAnulacion.clima);
  });
}
