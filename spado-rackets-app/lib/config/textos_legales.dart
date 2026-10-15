/// Textos legales de la app. Base de trabajo: debe revisarlos un abogado antes
/// de abrir la app a las familias, y el club debe completar sus datos de
/// contacto (marcados entre corchetes).
abstract final class TextosLegales {
  /// Se sube la versión cuando cambia el texto; el consentimiento de cada
  /// familia guarda con qué versión se aceptó.
  static const version = '2026-10';

  static const privacidadTitulo = 'Política de privacidad';

  static const privacidad = [
    (
      '¿Quién es el responsable?',
      'Spado Rackets (en adelante, «el club»). Contacto para cualquier '
          'asunto de privacidad: [correo del club].',
    ),
    (
      '¿Qué datos tratamos?',
      '• De las familias: nombre, correo electrónico y teléfono (opcional).\n'
          '• De las alumnas: nombre, grupo de entrenamiento, asistencia a '
          'clase y cuotas.\n'
          '• Justificantes de pago que la familia sube a la app, que pueden '
          'contener datos bancarios.\n'
          '• Mensajes que las familias y el club se envían por el chat.\n'
          '• De los entrenadores: hora y ubicación de su llegada al fichar.',
    ),
    (
      '¿Para qué los usamos?',
      'Para gestionar la escuela: registrar la asistencia, avisar a la '
          'familia de que su hija está en el entrenamiento, cobrar y '
          'justificar las cuotas, emitir recibos y comunicarnos con las '
          'familias. No los usamos para publicidad ni los cedemos a terceros.',
    ),
    (
      '¿Quién puede ver cada dato?',
      '• Cada familia ve únicamente a sus hijas, sus cuotas, su asistencia y '
          'sus conversaciones.\n'
          '• Los entrenadores ven las alumnas y listas de los grupos que '
          'tienen asignados.\n'
          '• La dirección del club puede ver toda la información de la '
          'escuela.\n'
          'Un justificante de pago sólo lo puede abrir la familia que lo '
          'subió y la dirección.',
    ),
    (
      'Base legal',
      'Tu consentimiento, que das al crear la cuenta, y la ejecución del '
          'servicio de la escuela. Los datos se tratan conforme a la Ley '
          'núm. 172-13 sobre Protección Integral de los Datos Personales de '
          'la República Dominicana.',
    ),
    (
      '¿Dónde se guardan y cuánto tiempo?',
      'En servidores de Google Firebase, con acceso restringido por perfil y '
          'conexión cifrada. Los conservamos mientras la alumna esté en la '
          'escuela y el tiempo necesario para atender obligaciones '
          'administrativas y contables.',
    ),
    (
      'Tus derechos',
      'Puedes pedir en cualquier momento acceder a tus datos, rectificarlos, '
          'actualizarlos o solicitar que se eliminen, y retirar tu '
          'consentimiento, escribiendo a [correo del club].',
    ),
  ];

  static const terminosTitulo = 'Condiciones de uso';

  static const terminos = [
    (
      'Uso de la app',
      'La app es una herramienta de la escuela para sus familias y '
          'entrenadores. Cada cuenta es personal: no compartas tu '
          'contraseña.',
    ),
    (
      'Mensajes',
      'El chat es para asuntos de la escuela. No se permiten insultos, '
          'publicidad ni compartir datos personales de terceros. La dirección '
          'puede retirar mensajes que incumplan estas normas.',
    ),
    (
      'Pagos',
      'Las cuotas se pagan por transferencia a las cuentas que figuran en la '
          'sección «Pagos», dentro de los 5 primeros días de cada mes, y se '
          'confirman cuando la dirección valida el justificante. La app no '
          'cobra con tarjeta.',
    ),
    (
      'Cambios',
      'Si estas condiciones o la política de privacidad cambian de forma '
          'relevante, te lo comunicaremos en la app.',
    ),
  ];
}
