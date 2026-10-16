/// Textos legales de la app. Base de trabajo: debe revisarlos un abogado antes
/// de abrir la app a las familias.
abstract final class TextosLegales {
  /// Se sube la versión cuando cambia el texto; el consentimiento de cada
  /// familia guarda con qué versión se aceptó.
  static const version = '2026-10-5';

  /// Versión del aviso que se enseña al staff antes de fichar.
  static const avisoStaffVersion = '2026-10';

  static const avisoStaffTitulo = 'Aviso sobre el fichaje y tu ubicación';

  static const avisoStaff = [
    (
      '¿Qué se registra?',
      'Solo cuando pulsas «Fichar llegada»: el día y la hora, y la ubicación '
          'aproximada de tu dispositivo en ese momento (coordenadas y '
          'precisión). La app no te sigue ni consulta tu ubicación en ningún '
          'otro momento.',
    ),
    (
      '¿Para qué?',
      'Para comprobar que la llegada al club se produce en el club, y llevar '
          'el control de asistencia del personal. No se usa para ninguna otra '
          'finalidad.',
    ),
    (
      '¿Quién lo ve?',
      'Tú y la dirección del club. Las familias no ven los fichajes.',
    ),
    (
      '¿Cuánto tiempo?',
      'El tiempo necesario para el control de asistencia del personal y las '
          'obligaciones del club. Puedes pedir información, rectificación o '
          'supresión escribiendo a info@mongogroupsport.com o desde Más → '
          'Descargar mis datos / Eliminar mi cuenta.',
    ),
  ];

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
          '• Del alumnado (niñas, niños y personas adultas): nombre, fecha de nacimiento, '
          'nivel de tenis, fotografía, días y hora de clase, asistencia y '
          'cuotas. En el caso de menores de edad los facilita y autoriza su '
          'madre, padre o tutor legal, también para la fotografía, que sirve para identificar a '
          'a la persona en clase y solo la ven su familia, su entrenador y la '
          'dirección.\n'
          '• Justificantes de pago que la familia sube a la app, que pueden '
          'contener datos bancarios.\n'
          '• Mensajes que las familias y el club se envían por el chat.\n'
          '• De los entrenadores: día y hora de su llegada y la ubicación '
          'del dispositivo en ese momento (solo al fichar).\n'
          '• Si activas los avisos: un identificador del dispositivo para '
          'enviarte notificaciones, que pueden mostrar el nombre de pila de la '
          'alumno o alumna al confirmar su asistencia.',
    ),
    (
      '¿Para qué los usamos?',
      'Para gestionar la escuela: registrar la asistencia, avisar a la '
          'familia de que su hijo o hija está en el entrenamiento, cobrar y validar '
          'las cuotas y comunicarnos con las familias. La ubicación del '
          'entrenador sirve solo para comprobar que ficha en el club. No '
          'usamos los datos para publicidad ni los vendemos o cedemos a '
          'terceros.',
    ),
    (
      '¿Quién puede ver cada dato?',
      '• Cada familia ve únicamente a sus hijos e hijas, sus cuotas, su asistencia y '
          'sus conversaciones.\n'
          '• Los entrenadores ven al alumnado y las listas de asistencia.\n'
          '• La dirección del club puede ver toda la información de la '
          'escuela, incluidas todas las conversaciones del chat (también las '
          'privadas), para poder atender consultas y moderar.\n'
          'Un justificante de pago solo lo puede abrir la familia que lo '
          'subió y la dirección.',
    ),
    (
      'Base legal',
      'Tu consentimiento, que das al crear la cuenta (y, en el caso de los '
          'menores, el de su madre, padre o tutor legal), y la ejecución del '
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
      'Mientras la persona esté en la escuela y el tiempo necesario para '
          'atender obligaciones administrativas y contables. Cuando dejes de '
          'usar la app puedes pedirnos que eliminemos tu cuenta y tus datos '
          '(salvo lo que el club deba conservar por ley).',
    ),
    (
      'Tus derechos',
      'Puedes pedir en cualquier momento acceder a tus datos, rectificarlos, '
          'actualizarlos o solicitar que se eliminen, y retirar tu '
          'consentimiento, desde Más → Descargar mis datos / Eliminar mi cuenta, o escribiendo a '
          'info@mongogroupsport.com.',
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
