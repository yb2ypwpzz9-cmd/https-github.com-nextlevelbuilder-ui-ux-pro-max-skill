import 'package:flutter_test/flutter_test.dart';
import 'package:spado_rackets_app/config/club_config.dart';
import 'package:spado_rackets_app/models/pago.dart';

Pago cuota({DateTime? vence, EstadoPago estado = EstadoPago.pendiente}) => Pago(
      id: 'a1_2026-10',
      alumnaId: 'a1',
      alumnaNombre: 'Lucía',
      grupo: 'general',
      familiaUid: 'f1',
      periodo: '2026-10',
      importe: 60,
      moneda: Moneda.usd,
      estado: estado,
      venceEn: vence,
    );

void main() {
  test('sin plazo propio vence el día 5 y después sale vencida', () {
    final p = cuota();
    expect(p.fechaLimite, DateTime(2026, 10, 5));
    expect(p.vencidaEn(DateTime(2026, 10, 5)), isFalse);
    expect(p.vencidaEn(DateTime(2026, 10, 27)), isTrue);
  });

  test('con plazo propio no sale vencida hasta pasada esa fecha', () {
    final p = cuota(vence: DateTime(2026, 11, 1));
    expect(p.vencidaEn(DateTime(2026, 10, 27)), isFalse);
    expect(p.vencidaEn(DateTime(2026, 11, 1)), isFalse);
    expect(p.vencidaEn(DateTime(2026, 11, 2)), isTrue);
  });

  test('una cuota pagada nunca sale vencida', () {
    expect(
        cuota(estado: EstadoPago.pagado).vencidaEn(DateTime(2027, 1, 1)), isFalse);
  });
}
