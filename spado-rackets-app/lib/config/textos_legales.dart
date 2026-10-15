/// Textos legales de la app. Base de trabajo: debe revisarlos un abogado antes
/// de abrir la app a las familias.
abstract final class TextosLegales {
  /// Se sube la versión cuando cambia el texto; el consentimiento de cada
  /// familia guarda con qué versión se aceptó.
  static const version = '2026-10-2';

  static const privacidadTitulo = 'Política de privacidad';

  static const privacidad = [
    (
      '¿Quién es el responsable?',
      'Spado Rackets es una marca de Mongo Group Sport Business, que es el '
          'responsable del tratamiento de tus datos («el club»). Contacto '
          'para cualquier asunto de privacidad: info@mongogroupsport.com.',
    ),
    (
      '¿Qué datos tratamos?',
      '• De las familias: nombre, correo electrónico y teléfono (opcional).\n'
          '• De las alumnas (menores de edad): nombre, grupo de '
          'entrenamiento, asistencia a clase y cuotas. Los facilita y '
          'autoriza su madre, padre o tutor legal.\n'
          '• Justificantes de pago que la familia sube a la app, que pueden '
          'contener datos bancarios.\n'
          '• Mensajes que las familias y el club se envían por el chat.\n'
          '• De los entrenadores: día y hora de su llegada y la ubicación '
          'del dispositivo en ese momento (solo al fichar).\n'
          '• Si activas los avisos: un identificador del dispositivo para '
          'enviarte notificaciones.',
    ),
    (
      '¿Para qué los usamos?',
      'Para gestionar la escuela: registrar la asistencia, avisar a la '
          'familia de que su hija está en el entrenamiento, cobrar y validar '
          'las cuotas y comunicarnos con las familias. La ubicación del '
          'entrenador sirve solo para comprobar que ficha en el club. No '
          'usamos los datos para publicidad ni los vendemos o cedemos a '
          'terceros.',
    ),
    (
      '¿Quién puede ver cada dato?',
      '• Cada familia ve únicamente a sus hijas, sus cuotas, su asistencia y '
          'sus conversaciones.\n'
          '• Los entrenadores ven las alumnas y listas de los grupos que '
          'tienen asignados.\n'
          '• La dirección del club puede ver toda la información de la '
          'escuela, incluidas todas las conversaciones del chat (también las '
          'privadas), para poder atender consultas y moderar.\n'
          'Un justificante de pago solo lo puede abrir la familia que lo '
          'subió y la dirección.',
    ),
    (
      'Base legal',
      'Tu consentimiento, que das al crear la cuenta (y, en el caso de las '
          'alumnas, el de su madre, padre o tutor legal), y la ejecución del '
          'servicio de la escuela. Los datos se tratan conforme a la Ley '
          'núm. 172-13 sobre Protección Integral de los Datos Personales de '
          'la República Dominicana.',
    ),
    (
      '¿Dónde se guardan y con quién?',
      'En servidores de Google (Firebase), ubicados en Estados Unidos, y la '
          'web se aloja en Netlify, que registra la dirección IP de las '
          'visitas. Ambos actúan como proveedores del club y los datos '
          'viajan cifrados. Si abres la ubicación de un fichaje desde la app, '
          'se abre Google Maps, que recibirá esas coordenadas.',
    ),
    (
      '¿Cuánto tiempo los conservamos?',
      'Mientras la alumna esté en la escuela y el tiempo necesario para '
          'atender obligaciones administrativas y contables. Cuando dejes de '
          'usar la app puedes pedirnos que eliminemos tu cuenta y tus datos '
          '(salvo lo que el club deba conservar por ley).',
    ),
    (
      'Tus derechos',
      'Puedes pedir en cualquier momento acceder a tus datos, rectificarlos, '
          'actualizarlos o solicitar que se eliminen, y retirar tu '
          'consentimiento, escribiendo a info@mongogroupsport.com.',
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
