import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/asistencia.dart';
import '../../models/grupo.dart';
import '../../models/jornada.dart';
import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../app_shell.dart';
import 'pagos_direccion_screen.dart' show revisarPago;

/// Panel de Dirección: lo que necesita atención hoy, arriba.
class DireccionHomeScreen extends StatelessWidget {
  const DireccionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();
    final hoy = DateTime.now();
    final hace14 = claveFecha(hoy.subtract(const Duration(days: 14)));

    return Scaffold(
      appBar: const TabAppBar(title: 'Panel de Dirección'),
      body: StreamView<List<Grupo>>(
        stream: repo.watchGrupos(),
        builder: (context, grupos) => StreamView<List<AppUser>>(
          stream: repo.watchCuentasDelClub(),
          builder: (context, cuentas) => StreamView<List<Jornada>>(
            stream: repo.watchJornadasDesde(
              DateTime(hoy.year, hoy.month, hoy.day)
                  .subtract(const Duration(days: 1)),
            ),
            builder: (context, jornadas) => StreamView<List<Asistencia>>(
              stream: repo.watchAsistenciaDesde(hace14),
              builder: (context, marcas) => StreamView<List<Pago>>(
                stream: repo.watchPagosSinCobrar(),
                builder: (context, sinCobrar) => StreamView<List<Pago>>(
                  stream: repo.watchPagosEnRevision(),
                  builder: (context, enRevision) => _Contenido(
                    user: user,
                    grupos: grupos.where((g) => g.activo).toList(),
                    staff: cuentas.where((c) => c.role.isStaff).toList(),
                    abiertas: jornadas.where((j) => _esHoy(j.entrada)).toList(),
                    marcas: marcas,
                    vencidas:
                        sinCobrar.where((p) => p.vencidaEn(hoy)).toList(),
                    enRevision: enRevision,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.user,
    required this.grupos,
    required this.staff,
    required this.abiertas,
    required this.marcas,
    required this.vencidas,
    required this.enRevision,
  });

  final AppUser user;
  final List<Grupo> grupos;
  final List<AppUser> staff;
  final List<Jornada> abiertas;
  final List<Asistencia> marcas;
  final List<Pago> vencidas;
  final List<Pago> enRevision;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final claveHoy = claveFecha(hoy);
    final t = Theme.of(context).textTheme;
    final irA = context.read<IrATab>();
    final clasesHoy = grupos.where((g) => g.tieneClaseEl(hoy)).toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    final listasHechas = {
      for (final m in marcas.where((m) => m.fecha == claveHoy)) m.grupo,
    };

    return PageBody(
      children: [
        Text(capitalizar(fechaLargaFormat.format(hoy)), style: t.bodySmall),
        Text('Hola, ${user.nombreVisible.split(' ').first}',
            style: t.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        KpiGrid(children: [
          KpiTile(
            valor: '${abiertas.length}/${staff.length}',
            etiqueta: 'Entrenadores que han fichado hoy',
            icon: Icons.badge_outlined,
            onTap: () => irA('Fichajes'),
          ),
          KpiTile(
            valor: marcas.isEmpty ? '—' : '${porcentajeAsistencia(marcas)}%',
            etiqueta: 'Asistencia 14 días',
            icon: Icons.fact_check_outlined,
            color: AppColors.success,
            onTap: () => context.push('/asistencia'),
          ),
          KpiTile(
            valor: '${enRevision.length}',
            etiqueta: 'Justificantes por revisar',
            icon: Icons.mark_email_unread_outlined,
            color: enRevision.isEmpty ? AppColors.navy : AppColors.info,
            onTap: () => irA('Pagos'),
          ),
          KpiTile(
            valor: '${vencidas.length}',
            etiqueta: 'Cuotas vencidas',
            icon: Icons.warning_amber_rounded,
            color: vencidas.isEmpty ? AppColors.navy : AppColors.danger,
            onTap: () => irA('Pagos'),
          ),
        ]),
        if (enRevision.isNotEmpty) ...[
          const SectionHeader(
            'Por revisar',
            subtitle: 'Justificantes subidos por las familias',
          ),
          CardList(
            children: [
              for (final p in enRevision)
                ListTile(
                  title: Text('${p.alumnaNombre} · ${p.periodoLabel}'),
                  subtitle: Text(formatoImporte(p.importe, p.moneda)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => revisarPago(context, p),
                ),
            ],
          ),
        ],
        const SectionHeader('Hoy en el club'),
        CardList(
          children: [
            if (staff.isEmpty)
              const ListTile(
                title: Text('Aún no hay cuentas de staff'),
                subtitle: Text('Créalas desde Más → Equipo'),
              ),
            for (final s in staff)
              Builder(builder: (context) {
                final j = abiertas.where((j) => j.staffUid == s.uid).firstOrNull;
                return ListTile(
                  leading: Avatar(s.iniciales),
                  title: Text(s.nombreVisible),
                  subtitle: Text(
                    s.grupos.isEmpty
                        ? 'Sin grupos'
                        : grupos
                            .where((g) => s.grupos.contains(g.id))
                            .map((g) => g.nombre)
                            .join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: j == null
                      ? const StatusChip(
                          label: 'Sin fichar',
                          color: AppColors.textSecondary,
                        )
                      : StatusChip(
                          label: 'Llegó ${horaFormat.format(j.entrada)}',
                          color: AppColors.success,
                          icon: Icons.check,
                        ),
                );
              }),
          ],
        ),
        const SectionHeader('Clases de hoy'),
        if (clasesHoy.isEmpty)
          const EmptyState(
            compacto: true,
            icon: Icons.event_available_outlined,
            title: 'Hoy no hay clases programadas',
          )
        else
          CardList(
            children: [
              for (final g in clasesHoy)
                ListTile(
                  title: Text(g.nombre),
                  subtitle: Text(
                    [g.horaInicio, if (g.pista.isNotEmpty) g.pista].join(' · '),
                  ),
                  trailing: listasHechas.contains(g.id)
                      ? const StatusChip(
                          label: 'Lista hecha',
                          color: AppColors.success,
                          icon: Icons.check,
                        )
                      : const StatusChip(
                          label: 'Sin lista',
                          color: AppColors.warning,
                        ),
                  onTap: () => context.push('/lista/${g.id}?fecha=$claveHoy'),
                ),
            ],
          ),
        const SectionHeader('Gestión'),
        const CardList(
          children: [
            _Enlace(Icons.school_outlined, 'Alumnas y códigos', '/alumnas'),
            _Enlace(Icons.groups_outlined, 'Grupos, horarios y cuotas', '/grupos'),
            _Enlace(Icons.badge_outlined, 'Equipo y cuentas', '/equipo'),
            _Enlace(Icons.fact_check_outlined, 'Asistencia por grupo', '/asistencia'),
            _Enlace(Icons.account_balance_outlined, 'Datos bancarios', '/datos-bancarios'),
          ],
        ),
      ],
    );
  }
}

class _Enlace extends StatelessWidget {
  const _Enlace(this.icon, this.titulo, this.ruta);
  final IconData icon;
  final String titulo;
  final String ruta;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.navy),
        title: Text(titulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(ruta),
      );
}

bool _esHoy(DateTime f) {
  final h = DateTime.now();
  return f.year == h.year && f.month == h.month && f.day == h.day;
}
