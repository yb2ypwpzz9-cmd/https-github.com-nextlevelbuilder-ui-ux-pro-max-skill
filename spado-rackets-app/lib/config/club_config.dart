/// Datos fijos del club. Lo que Dirección puede cambiar sin tocar código
/// (cuentas bancarias, importes) vive en Firestore: `ajustes/club` y `grupos`.
abstract final class ClubConfig {
  static const nombre = 'Spado Rackets';
  static const nombreCorto = 'Spado Rackets';

  /// Las cuotas de Spado Rackets se fijan y se cobran en dólares: no deben
  /// aparecer en pesos en ninguna pantalla.
  static const monedaPorDefecto = Moneda.usd;

  /// Último día del mes para pagar la cuota (primeros 5 días del mes). Rackets
  /// no aplica recargo por mora: pasado el día 5 sólo se marca como vencida.
  static const diaVencimientoCuota = 5;

  /// Zona horaria del club. Se usa en las funciones de servidor; en la app
  /// manda la hora del dispositivo, que en RD es la misma.
  static const zonaHoraria = 'America/Santo_Domingo';

  /// Región de las Cloud Functions, la más cercana a República Dominicana.
  static const regionFunciones = 'us-east1';

  /// Grupo interno al que pertenecen todos los alumnos nuevos. Ya no se elige
  /// grupo: cada alumno tiene su propio horario y su propia cuota.
  static const grupoGeneral = 'general';

  /// Clave pública VAPID para las notificaciones web. Se saca de la consola de
  /// Firebase: Configuración del proyecto → Cloud Messaging → Certificados
  /// push web. Vacía = la app funciona igual, pero sin avisos push.
  static const vapidKey =
      'BPgfdfBQjhgb-lhw4X0jVlN6ZqfX2cOwoXmUHQ7X6ZcACebapfndsXl_twkm1_PPBnWDWZKjcROAhh1Tnh8fQrs';

  /// Clave de sitio de reCAPTCHA Enterprise (Fraud Defense) para Firebase App
  /// Check. Es pública. Vacía = App Check apagado y la app funciona igual.
  static const appCheckKey = '6LdHEQUuAAAAAJiT9XrEyfL-k4iBh5DZnvD3QJfq';

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
