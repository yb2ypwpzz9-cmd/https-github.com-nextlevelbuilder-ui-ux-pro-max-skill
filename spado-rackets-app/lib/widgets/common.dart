import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

// Formato dominicano: 12 h con a. m. / p. m.
final fechaFormat = DateFormat('dd/MM/yyyy', 'es');
final fechaLargaFormat = DateFormat("EEEE d 'de' MMMM", 'es');
final fechaCortaFormat = DateFormat('EEE d MMM', 'es');
final horaFormat = DateFormat('h:mm a', 'es');
final fechaHoraFormat = DateFormat('dd/MM/yyyy h:mm a', 'es');

String capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Contenido con ancho máximo y márgenes. En el ordenador de Dirección evita
/// líneas de lado a lado; en el móvil no cambia nada.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
          children: children,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleLarge?.copyWith(fontSize: 19)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: t.bodySmall),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compacto = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compacto ? 30 : 42, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: t.titleMedium, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpacing.md),
          action!,
        ],
      ],
    );
    if (compacto) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(child: contenido),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: contenido,
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pinta un stream con estados de carga y error explícitos.
///
/// Si en 12 segundos no llega nada, lo dice en lugar de dejar el indicador
/// girando para siempre: con mala cobertura es lo que más confunde.
class StreamView<T> extends StatefulWidget {
  const StreamView({
    super.key,
    required this.stream,
    required this.builder,
    this.loading,
  });

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>> {
  late Stream<T> _stream;
  Timer? _timer;
  bool _lento = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.stream;
    _arrancarTemporizador();
  }

  void _arrancarTemporizador() {
    _timer?.cancel();
    _lento = false;
    _timer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _lento = true);
    });
  }

  @override
  void didUpdateWidget(covariant StreamView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stream, widget.stream)) {
      _stream = widget.stream;
      _arrancarTemporizador();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          _timer?.cancel();
          return ErrorView(error: snap.error);
        }
        if (!snap.hasData) {
          if (_lento) {
            return const EmptyState(
              icon: Icons.wifi_off_outlined,
              title: 'Está tardando más de lo normal',
              message: 'Revisa tu conexión. Los datos aparecerán en cuanto '
                  'lleguen.',
              compacto: true,
            );
          }
          return widget.loading ?? const LoadingView();
        }
        _timer?.cancel();
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final texto = '$error';
    final permisos = texto.contains('permission-denied');
    final indice = texto.contains('failed-precondition') &&
        texto.contains('index');
    return EmptyState(
      icon: Icons.error_outline,
      compacto: true,
      title: permisos
          ? 'No tienes acceso a esta información'
          : 'No se pudo cargar',
      message: permisos
          ? 'Si crees que es un error, avisa a Dirección.'
          : indice
              ? 'Falta un índice en la base de datos. Avisa a quien mantiene '
                  'la app: se arregla desplegando firestore.indexes.json.'
              : 'Revisa tu conexión e inténtalo de nuevo.',
    );
  }
}

/// Etiqueta de estado: color + texto (nunca sólo color).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.iniciales, {super.key, this.size = 38, this.color});

  final String iniciales;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.navy;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        iniciales,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// Cifra destacada del panel. Tocable si lleva [onTap].
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.valor,
    required this.etiqueta,
    this.color,
    this.icon,
    this.onTap,
  });

  final String valor;
  final String etiqueta;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Icon(icon, size: 18, color: color ?? AppColors.navy),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                valor,
                style: t.headlineMedium?.copyWith(
                  color: color ?? AppColors.navy,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(etiqueta, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rejilla de dos columnas que pasa a cuatro en pantalla ancha.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth > 620 ? 4 : 2;
        final ancho =
            (c.maxWidth - AppSpacing.sm * (columnas - 1)) / columnas;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final w in children) SizedBox(width: ancho, child: w),
          ],
        );
      },
    );
  }
}

/// Aviso dentro de una pantalla (información, advertencia o error).
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = AppColors.info,
    this.action,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista dentro de una tarjeta, con separadores.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.md),
            children[i],
          ],
        ],
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.navyDeep,
      ),
    );
}

/// Confirmación antes de una acción que no se deshace fácilmente.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  bool peligrosa = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: peligrosa ? AppColors.danger : AppColors.navy,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return r ?? false;
}
