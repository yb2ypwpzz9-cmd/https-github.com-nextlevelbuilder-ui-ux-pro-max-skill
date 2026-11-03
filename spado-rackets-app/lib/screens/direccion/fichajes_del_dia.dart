import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../models/jornada.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Quién ha fichado un día y quién no, con un botón para recordárselo a cada
/// entrenador que falta (aviso al móvil; si no tiene avisos, se le escribe por
/// el chat).
class FichajesDelDia extends StatefulWidget {
  const FichajesDelDia({super.key});

  @override
  State<FichajesDelDia> createState() => _FichajesDelDiaState();
}

class _FichajesDelDiaState extends State<FichajesDelDia> {
  late final ClubRepository _repo = context.read<ClubRepository>();
  late final Stream<List<AppUser>> _cuentas = _repo.watchCuentasDelClub();
  DateTime _dia = _soloDia(DateTime.now());
  String? _enviando;

  static DateTime _soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _esHoy => _dia == _soloDia(DateTime.now());

  Future<void> _recordar(AppUser persona) async {
    final yo = context.read<SessionController>().appUser!;
    setState(() => _enviando = persona.uid);
    try {
      final r = await _repo.recordarFichaje(persona.uid);
      if (!mounted) return;
      if (r.enviado) {
        showAppSnackBar(context, 'Recordatorio enviado a ${persona.nombreVisible}.');
      } else if (r.motivo == 'ya-ficho') {
        showAppSnackBar(context, '${persona.nombreVisible} ya ha fichado.');
      } else {
        final escribir = await confirmar(
          context,
          titulo: '${persona.nombreVisible} no recibe avisos',
          mensaje: 'No tiene las notificaciones activadas en su móvil. ¿Le '
              'escribes por el chat?',
          accion: 'Escribir por el chat',
        );
        if (escribir && mounted) {
          context.push('/chat/${Conversacion.idDirecta(yo.uid, persona.uid)}');
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '$e'.replaceFirst('Exception: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _enviando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Fichajes del día'),
        Card(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Día anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                    () => _dia = _dia.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: _dia,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now(),
                    );
                    if (f != null) setState(() => _dia = _soloDia(f));
                  },
                  child: Text(
                    _esHoy
                        ? 'Hoy · ${capitalizar(fechaLargaFormat.format(_dia))}'
                        : capitalizar(fechaLargaFormat.format(_dia)),
                    style: t.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Día siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: _esHoy
                    ? null
                    : () => setState(
                        () => _dia = _dia.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamView<List<AppUser>>(
          stream: _cuentas,
          builder: (context, cuentas) => StreamView<List<Jornada>>(
            streamKey: _dia,
            stream: _repo.watchJornadasDesde(_dia),
            builder: (context, jornadas) {
              final staff = cuentas.where((c) => c.role.isStaff).toList();
              final fin = _dia.add(const Duration(days: 1));
              final delDia = {
                for (final j in jornadas)
                  if (!j.entrada.isBefore(_dia) && j.entrada.isBefore(fin))
                    j.staffUid: j,
              };
              if (staff.isEmpty) {
                return const EmptyState(
                  compacto: true,
                  icon: Icons.badge_outlined,
                  title: 'Todavía no hay entrenadores',
                  message: 'Crea sus cuentas en Más → Equipo y cuentas.',
                );
              }
              final faltan = staff
                  .where((c) => !delDia.containsKey(c.uid) && !c.pendienteActivacion)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusChip(
                    label: faltan.isEmpty
                        ? 'Han fichado todos'
                        : '${staff.length - faltan.length} de ${staff.length} '
                            'han fichado',
                    color: faltan.isEmpty ? AppColors.success : AppColors.warning,
                    icon: faltan.isEmpty ? Icons.check : Icons.schedule,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CardList(
                    children: [
                      for (final c in staff)
                        _FilaPersona(
                          persona: c,
                          jornada: delDia[c.uid],
                          esHoy: _esHoy,
                          enviando: _enviando == c.uid,
                          onRecordar: () => _recordar(c),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _FilaPersona extends StatelessWidget {
  const _FilaPersona({
    required this.persona,
    required this.jornada,
    required this.esHoy,
    required this.enviando,
    required this.onRecordar,
  });

  final AppUser persona;
  final Jornada? jornada;
  final bool esHoy;
  final bool enviando;
  final VoidCallback onRecordar;

  @override
  Widget build(BuildContext context) {
    final j = jornada;
    return ListTile(
      leading: Avatar(persona.iniciales),
      title: Text(persona.nombreVisible),
      subtitle: Text(j != null
          ? 'Fichó a las ${horaFormat.format(j.entrada)}'
              '${j.entradaConUbicacion ? '' : ' · sin ubicación'}'
          : persona.pendienteActivacion
              ? 'Aún no ha activado su cuenta'
              : esHoy
                  ? 'Todavía no ha fichado'
                  : 'No fichó este día'),
      trailing: j != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (j.mapaEntrada != null)
                  IconButton(
                    tooltip: 'Ver ubicación',
                    icon: const Icon(Icons.place_outlined,
                        color: AppColors.navy),
                    onPressed: () => launchUrl(j.mapaEntrada!,
                        webOnlyWindowName: '_blank'),
                  ),
                const Icon(Icons.check_circle, color: AppColors.success),
              ],
            )
          : (esHoy && !persona.pendienteActivacion)
              ? FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: enviando ? null : onRecordar,
                  child: Text(enviando ? 'Enviando…' : 'Recordar'),
                )
              : const Icon(Icons.cancel_outlined, color: AppColors.danger),
    );
  }
}
