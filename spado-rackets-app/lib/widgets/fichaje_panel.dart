import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/club_config.dart';
import '../models/jornada.dart';
import '../services/auth_service.dart';
import '../services/club_repository.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Fichaje de llegada del entrenador, con ubicación.
///
/// Sólo se ficha la llegada, una vez al día. La hora la pone el servidor y la
/// ubicación se pide en el momento: nunca se reutiliza una anterior.
class FichajePanel extends StatefulWidget {
  const FichajePanel({super.key});

  @override
  State<FichajePanel> createState() => _FichajePanelState();
}

class _FichajePanelState extends State<FichajePanel> {
  bool _trabajando = false;

  Future<void> _fichar() async {
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
      await repo.ficharLlegada(user, ubicacion);
      if (mounted) showAppSnackBar(context, 'Llegada registrada.');
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
    final t = Theme.of(context).textTheme;

    return StreamBuilderEstable<Jornada?>(
      streamKey: uid,
      stream: context.read<ClubRepository>().watchFichajeHoy(uid),
      builder: (context, snap) {
        // "Aún no ha fichado" llega como `null`, que para StreamBuilder es
        // `hasData == false`: lo que indica que no sabemos nada es la conexión.
        final cargando = snap.connectionState == ConnectionState.waiting;
        final fichaje = snap.data;
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
                    'FICHAJE DE LLEGADA',
                    style: t.labelSmall?.copyWith(
                      color: AppColors.ball,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    fichaje == null
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle,
                    size: 18,
                    color: fichaje == null
                        ? Colors.white38
                        : const Color(0xFF4ADE80),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                fichaje == null
                    ? horaFormat.format(ahora)
                    : 'Llegaste a las ${horaFormat.format(fichaje.entrada)}',
                style: t.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: fichaje == null ? null : 30,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fichaje == null
                    ? capitalizar(fechaLargaFormat.format(ahora))
                    : fichaje.entradaConUbicacion
                        ? 'Ubicación registrada. ¡Buen entrenamiento!'
                        : 'Fichado sin ubicación.',
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
              if (fichaje == null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _trabajando || cargando ? null : _fichar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ball,
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
                      : const Icon(Icons.where_to_vote_outlined),
                  label: Text(
                    _trabajando ? 'Obteniendo ubicación…' : 'Fichar llegada',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Se registra la hora del servidor y tu ubicación en ese '
                  'momento.',
                  style: TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
