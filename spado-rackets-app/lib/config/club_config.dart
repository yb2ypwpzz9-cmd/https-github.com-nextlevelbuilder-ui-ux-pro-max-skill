/// Datos fijos del club. Lo que Dirección puede cambiar sin tocar código
/// (cuentas bancarias, importes) vive en Firestore: `ajustes/club` y `grupos`.
abstract final class ClubConfig {
  static const nombre = 'Spado Rackets';
  static const nombreCorto = 'Spado Rackets';

  /// Moneda por defecto de las cuotas. El club cobra en pesos y, como mucho,
  /// en dólares: cada grupo elige una de las dos.
  static const monedaPorDefecto = Moneda.dop;

  /// Último día del mes para pagar la cuota sin que salga como vencida.
  static const diaVencimientoCuota = 10;

  /// Zona horaria del club. Se usa en las funciones de servidor; en la app
  /// manda la hora del dispositivo, que en RD es la misma.
  static const zonaHoraria = 'America/Santo_Domingo';

  /// Región de las Cloud Functions, la más cercana a República Dominicana.
  static const regionFunciones = 'us-east1';

  /// Clave pública VAPID para las notificaciones web. Se saca de la consola de
  /// Firebase: Configuración del proyecto → Cloud Messaging → Certificados
  /// push web. Vacía = la app funciona igual, pero sin avisos push.
  static const vapidKey = '';

  /// El fichaje exige ubicación, como en Spado Soccer: un fichaje sin posición
  /// no demuestra que el entrenador estuviera en la pista.
  static const fichajeExigeUbicacion = true;
}

enum Moneda {
  dop(r'RD$', 'Pesos dominicanos'),
  usd(r'US$', 'Dólares');

  const Moneda(this.simbolo, this.nombre);
  final String simbolo;
  final String nombre;

  String get wire => name.toUpperCase();

  static Moneda fromString(String? valor) =>
      valor?.toUpperCase() == 'USD' ? Moneda.usd : Moneda.dop;
}
