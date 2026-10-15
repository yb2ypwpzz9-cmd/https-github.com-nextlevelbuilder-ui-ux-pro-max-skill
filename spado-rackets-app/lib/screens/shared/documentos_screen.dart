import 'package:flutter/material.dart';

import '../../config/textos_legales.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Textos legales. Accesibles sin iniciar sesión: una familia tiene que poder
/// leer la política de privacidad antes de crear su cuenta.
class DocumentosScreen extends StatelessWidget {
  const DocumentosScreen({super.key, required this.titulo, required this.secciones});

  factory DocumentosScreen.privacidad() => const DocumentosScreen(
        titulo: TextosLegales.privacidadTitulo,
        secciones: TextosLegales.privacidad,
      );

  factory DocumentosScreen.terminos() => const DocumentosScreen(
        titulo: TextosLegales.terminosTitulo,
        secciones: TextosLegales.terminos,
      );

  final String titulo;
  final List<(String, String)> secciones;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: PageBody(
        children: [
          for (final (encabezado, texto) in secciones) ...[
            Text(encabezado, style: t.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: AppSpacing.xs),
            Text(texto, style: t.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            'Versión ${TextosLegales.version}',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
