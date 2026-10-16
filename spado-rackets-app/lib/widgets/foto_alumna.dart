import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumna.dart';
import '../models/app_user.dart' show inicialesDe;
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Foto redonda de la alumna; si no tiene (o aún carga), sus iniciales.
class FotoAlumna extends StatelessWidget {
  const FotoAlumna(this.alumna, {super.key, this.size = 44});

  final Alumna alumna;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iniciales = inicialesDe(alumna.nombre);
    final ruta = alumna.fotoPath;
    if (ruta == null) return Avatar(iniciales, size: size);
    return FutureBuilder<Uint8List?>(
      future: context.read<ClubRepository>().fotoAlumna(ruta),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return Avatar(iniciales, size: size);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
