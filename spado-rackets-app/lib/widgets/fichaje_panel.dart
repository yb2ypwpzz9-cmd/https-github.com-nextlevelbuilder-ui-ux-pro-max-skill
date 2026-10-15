import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/club_config.dart';
import '../models/jornada.dart';
import '../services/auth_service.dart';
import '../services/club_repository.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Fichaje de entrada y salida del staff, con ubicación.
///
/// La hora la pone el servidor. La ubicación se pide en el momento de fichar
/// y nunca se reutiliza una anterior.
class FichajePanel extends StatefulWidget {
  const FichajePanel({super.key});

  @override
  State<FichajePanel> createState() => _FichajePanelState();
}

class _FichajePanelState extends State<FichajePanel> {
  bool _trabajando = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca el contador de horas cada 30 s sin tocar la red.
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _fichar(Jornada? abierta) async {
    final user = context.read<SessionController>().appUser;
    if (user == null) return;
    final repo = context.read<ClubRepository>();
    setState(() => _trabajando = true);

    try {
      final resultado = await const UbicacionService().obtener();
      UbicacionObtenida? ubicacion;
      if (resultado is UbicacionNoDisponible) {
        if (ClubConfig.fichajeExigeUbicacion) {
          if (mounted) showAppSnackBar(context, resultado.motivo, isError: true);
          return;
        }
      } else {
        ubicacion = resultado as UbicacionObtenida;
      }

      if (abierta == null) {
        await repo.ficharEntrada(user, ubicacion);
        if (mounted) showAppSnackBar(context, 'Entrada registrada.');
      } else {
        await repo.ficharSalida(abierta, ubicacion);
        if (mounted) {
          showAppSnackBar(
            context,
            'Salida registrada. Jornada de '
            '${formatoDuracion(abierta.duracionHasta(DateTime.now()))}.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo registrar el fichaje. Revisa tu conexión e inténtalo '
          'otra vez.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<SessionController>().appUser!.uid;
    final repo = context.read<ClubRepository>();
    final t = Theme.of(context).textTheme;

    return StreamBuilder<Jornada?>(
      stream: repo.watchJornadaAbierta(uid),
      builder: (context, snap) {
        // Ojo: "sin jornada abierta" llega como `null`, que para StreamBuilder
        // es `hasData == false`. Lo que indica que aún no sabemos nada es el
        // estado de la conexión, no la ausencia de dato.
        final cargando = snap.connectionState == ConnectionState.waiting;
        final abierta = snap.data;
        final ahora = DateTime.now();

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.navyDeep,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'FICHAJE',
                    style: t.labelSmall?.copyWith(
                      color: AppColors.ball,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  _EstadoJornada(abierta: abierta != null),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                abierta == null
                    ? horaFormat.format(ahora)
                    : formatoDuracion(abierta.duracionHasta(ahora)),
                style: t.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                abierta == null
                    ? capitalizar(fechaLargaFormat.format(ahora))
                    : 'En jornada desde las ${horaFormat.format(abierta.entrada)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed:
                    _trabajando || cargando ? null : () => _fichar(abierta),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      abierta == null ? AppColors.ball : Colors.white,
                  foregroundColor: AppColors.navyDeep,
                  disabledBackgroundColor: Colors.white24,
                ),
                icon: _trabajando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.navyDeep,
                        ),
                      )
                    : Icon(abierta == null ? Icons.login : Icons.logout),
                label: Text(
                  _trabajando
                      ? 'Obteniendo ubicación…'
                      : abierta == null
                          ? 'Fichar entrada'
                          : 'Fichar salida',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Se registra la hora del servidor y tu ubicación en ese '
                'momento.',
                style: TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EstadoJornada extends StatelessWidget {
  const _EstadoJornada({required this.abierta});
  final bool abierta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: abierta ? const Color(0xFF4ADE80) : Colors.white38,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          abierta ? 'En jornada' : 'Fuera de jornada',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
