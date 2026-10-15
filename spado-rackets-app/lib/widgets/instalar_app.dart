import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Hoja con los pasos para guardar la web en la pantalla de inicio del móvil.
void mostrarInstalarApp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tener Spado Rackets como una app',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            _Paso(
              icono: Icons.phone_iphone,
              titulo: 'iPhone (Safari)',
              texto: '1. Pulsa el botón Compartir (el cuadrado con la flecha '
                  'hacia arriba).\n'
                  '2. Elige "Añadir a pantalla de inicio".\n'
                  '3. Pulsa "Añadir". Aparecerá el logo del club.',
            ),
            SizedBox(height: 14),
            _Paso(
              icono: Icons.android,
              titulo: 'Android (Chrome)',
              texto: '1. Pulsa el menú ⋮ de arriba a la derecha.\n'
                  '2. Elige "Instalar aplicación" o "Añadir a pantalla de '
                  'inicio".\n'
                  '3. Confirma. Aparecerá el logo del club.',
            ),
            SizedBox(height: 14),
            Text(
              'Se abre a pantalla completa, como cualquier app, y siempre '
              'está actualizada. En iPhone hay que hacerlo desde Safari.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.titulo, required this.texto});
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: AppColors.navy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(texto, style: const TextStyle(height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
