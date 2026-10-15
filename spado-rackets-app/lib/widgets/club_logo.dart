import 'package:flutter/material.dart';

/// Logo oficial del club. [blanco] para fondos azules.
class ClubLogo extends StatelessWidget {
  const ClubLogo({super.key, this.height = 56, this.blanco = false});

  final double height;
  final bool blanco;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      blanco ? 'assets/images/logo_blanco.png' : 'assets/images/logo_azul.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Spado Rackets',
    );
  }
}

/// Sólo el emblema circular, para cabeceras compactas.
class ClubEmblema extends StatelessWidget {
  const ClubEmblema({super.key, this.size = 30, this.blanco = true});

  final double size;
  final bool blanco;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      blanco
          ? 'assets/images/emblema_blanco.png'
          : 'assets/images/emblema_azul.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}
