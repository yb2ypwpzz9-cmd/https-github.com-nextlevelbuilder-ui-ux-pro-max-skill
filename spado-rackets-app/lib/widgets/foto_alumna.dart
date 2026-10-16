import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumna.dart';
import '../models/app_user.dart' show inicialesDe;
import '../services/club_repository.dart';
import 'common.dart';

/// Foto redonda de la alumna; si no tiene (o aún carga), sus iniciales.
///
/// Se enseña como imagen del navegador (`<img>`): la descarga directa de
/// archivos de Storage exige configurar CORS en el bucket, y así no hace
/// falta.
class FotoAlumna extends StatelessWidget {
  const FotoAlumna(this.alumna, {super.key, this.size = 44});

  final Alumna alumna;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iniciales = inicialesDe(alumna.nombre);
    final ruta = alumna.fotoPath;
    if (ruta == null) return Avatar(iniciales, size: size);
    return FutureBuilder<String>(
      future: context.read<ClubRepository>().urlFotoAlumna(ruta),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null || url.isEmpty) return Avatar(iniciales, size: size);
        return SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              errorBuilder: (_, __, ___) => Avatar(iniciales, size: size),
            ),
          ),
        );
      },
    );
  }
}
