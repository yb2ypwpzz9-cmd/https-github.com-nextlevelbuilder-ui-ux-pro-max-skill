import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/app_user.dart';
import '../../models/asistencia.dart';
import '../../models/cambio_clase.dart';
import '../../models/chat.dart';
import '../../models/pago.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/foto_alumna.dart';
import '../../widgets/horario_alumna.dart' show textoCambioClase;
import '../app_shell.dart';
import '../staff/staff_grupos_screen.dart' show MarcaAsistencia;

/// Inicio de la familia: su hija, cómo va su asistencia y si debe algo.
class FamiliaHomeScreen extends StatefulWidget {
  const FamiliaHomeScreen({super.key});

  @override
  State<FamiliaHomeScreen> createState() => _FamiliaHomeScreenState();
}

class _FamiliaHomeScreenState extends State<FamiliaHomeScreen> {
  String? _alumnaId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    final repo = context.read<ClubRepository>();

    return Scaffold(
      appBar: const TabAppBar(title: 'Spado Rackets'),
      body: StreamView<List<Alumna>>(
        stream: repo.watchAlumnasDeFamilia(user.uid),
        builder: (context, alumnas) {
          if (alumnas.isEmpty) {
            final session = context.watch<SessionController>();
            if (user.codigoPendiente != null) {
              return const LoadingView(message: 'Vinculando a tu hijo o hija…');
            }
            return EmptyState(
              icon: Icons.link_off,
              title: 'Tu cuenta aún no tiene a nadie vinculado',
              message: session.errorVinculacion ??
                  'Añade el código que te dio el club desde "Más" → '
                      '"Vincular otro alumno/a".',
            );
          }
          final alumna = alumnas.firstWhere(
            (a) => a.id == _alumnaId,
            orElse: () => alumnas.first,
          );
          return PageBody(
            children: [
              if (alumnas.length > 1) ...[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final a in alumnas)
                      ChoiceChip(
                        label: Text(a.nombreCorto),
                        selected: a.id == alumna.id,
                        onSelected: (_) => setState(() => _alumnaId = a.id),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _Cabecera(alumna: alumna, familia: user),
              const SizedBox(height: AppSpacing.md),
              if (alumna.fotoPath == null) ...[
                _AvisoFoto(alumna: alumna),
                const SizedBox(height: AppSpacing.md),
              ],
              _ProximosCambios(alumna: alumna, uid: user.uid),
              _EstadoCuotas(uid: user.uid),
              _Asistencia(alumna: alumna, uid: user.uid),
              const _UltimoAviso(),
            ],
          );
        },
      ),
    );
  }
}

/// Cambios de clase que el club ha puesto para días concretos.
class _ProximosCambios extends StatelessWidget {
  const _ProximosCambios({required this.alumna, required this.uid});
  final Alumna alumna;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final hoy = claveFecha(DateTime.now());
    return StreamView<List<CambioClase>>(
      streamKey: uid,
      stream: context.read<ClubRepository>().watchCambiosFamilia(uid),
      builder: (context, todos) {
        final proximos = todos
            .where((c) => c.alumnaId == alumna.id && c.fecha.compareTo(hoy) >= 0)
            .toList();
        if (proximos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Cambios de clase'),
            CardList(
              children: [
                for (final c in proximos)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      c.tipo == TipoCambio.cancelada
                          ? Icons.event_busy_outlined
                          : Icons.event_available_outlined,
                      color: AppColors.navy,
                    ),
                    title: Text(textoCambioClase(c)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.alumna,
    required this.familia,
  });

  final Alumna alumna;
  final AppUser familia;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navyDeep,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (alumna.tipo?.label ?? 'Spado Rackets').toUpperCase(),
            style: t.labelSmall?.copyWith(
              color: AppColors.ball,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () => cambiarFotoAlumna(context, alumna),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FotoAlumna(alumna, size: 64),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.ball,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_camera,
                            size: 14, color: AppColors.navyDeep),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alumna.nombre,
                      style: t.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    if (alumna.edad != null || alumna.nivel != null)
                      Text(
                        [
                          if (alumna.edad != null) '${alumna.edad} años',
                          if (alumna.nivel != null)
                            'Nivel ${alumna.nivel!.label.toLowerCase()}',
                        ].join(' · '),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alumna.horarioTexto,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ball,
                  foregroundColor: AppColors.navyDeep,
                  minimumSize: const Size(0, 42),
                ),
                onPressed: () => _avisarFalta(context),
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text('Avisar de una falta'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  minimumSize: const Size(0, 42),
                ),
                onPressed: () => context.push('/chat/nueva'),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Escribir al entrenador o a Dirección'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _avisarFalta(BuildContext context) async {
    final repo = context.read<ClubRepository>();
    final motivo = TextEditingController();
    var fecha = DateTime.now();
    final enviado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Avisar falta de ${alumna.nombreCorto}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(capitalizar(fechaLargaFormat.format(fecha))),
                  trailing: const Text('Cambiar'),
                  onTap: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (f != null) setSheet(() => fecha = f);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: motivo,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Ej. cita médica, actividad del colegio',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'El entrenador la verá marcada como falta justificada al '
                'pasar lista.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enviar aviso'),
              ),
            ],
          ),
        ),
      ),
    );
    if (enviado != true) return;
    try {
      await repo.avisarAusencia(
        alumna: alumna,
        fecha: claveFecha(fecha),
        motivo: motivo.text,
        familia: familia,
      );
      if (context.mounted) showAppSnackBar(context, 'Aviso enviado al club.');
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo enviar el aviso.', isError: true);
      }
    }
  }
}

class _EstadoCuotas extends StatelessWidget {
  const _EstadoCuotas({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilderEstable<List<Pago>>(
      streamKey: uid,
      stream: context.read<ClubRepository>().watchPagosFamilia(uid),
      builder: (context, snap) {
        final pagos = snap.data;
        if (pagos == null) return const SizedBox.shrink();
        final pendientes = pagos.where((p) => p.necesitaAccionFamilia).toList();
        final enRevision =
            pagos.where((p) => p.estado == EstadoPago.enRevision).length;
        final t = Theme.of(context).textTheme;

        final (color, icono, titulo, texto) = pendientes.isNotEmpty
            ? (
                pendientes.any((p) => p.vencidaEn(DateTime.now()))
                    ? AppColors.danger
                    : AppColors.warning,
                Icons.receipt_long,
                pendientes.length == 1
                    ? 'Tienes 1 cuota por pagar'
                    : 'Tienes ${pendientes.length} cuotas por pagar',
                'Ver datos bancarios y subir el justificante',
              )
            : enRevision > 0
                ? (
                    AppColors.info,
                    Icons.hourglass_top,
                    'Justificante en revisión',
                    'El club lo está comprobando',
                  )
                : (
                    AppColors.success,
                    Icons.verified_outlined,
                    'Cuotas al día',
                    'No tienes nada pendiente',
                  );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 21),
            ),
            title: Text(titulo, style: t.titleSmall),
            subtitle: Text(texto),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.read<IrATab>()('Pagos'),
          ),
        );
      },
    );
  }
}

class _Asistencia extends StatelessWidget {
  const _Asistencia({required this.alumna, required this.uid});
  final Alumna alumna;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamView<List<Asistencia>>(
      stream: context.read<ClubRepository>().watchAsistenciaFamilia(uid),
      builder: (context, todas) {
        final marcas = todas.where((m) => m.alumnaId == alumna.id).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              'Asistencia',
              subtitle: marcas.isEmpty
                  ? null
                  : '${porcentajeAsistencia(marcas)}% de las clases',
            ),
            if (marcas.isEmpty)
              const EmptyState(
                compacto: true,
                icon: Icons.fact_check_outlined,
                title: 'Todavía no hay clases registradas',
                message: 'Aquí verás cada día que el entrenador pase lista.',
              )
            else
              CardList(
                children: [
                  for (final m in marcas.take(8))
                    ListTile(
                      dense: true,
                      leading: MarcaAsistencia(m.estado),
                      title: Text(
                        capitalizar(
                          fechaLargaFormat.format(fechaDeClave(m.fecha)),
                        ),
                        style: t.bodyMedium,
                      ),
                      trailing: Text(m.estado.label, style: t.labelMedium),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _UltimoAviso extends StatelessWidget {
  const _UltimoAviso();

  @override
  Widget build(BuildContext context) {
    return StreamBuilderEstable<Conversacion?>(
      stream: context
          .read<ClubRepository>()
          .watchConversacion(Conversacion.idAvisos),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null || c.ultimoMensaje.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Último aviso del club'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/chat/${Conversacion.idAvisos}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          c.ultimoAutor,
                          if (c.ultimoMensajeEn != null)
                            fechaHoraFormat.format(c.ultimoMensajeEn!),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(c.ultimoMensaje),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Invita a la familia a poner la foto de su hija (ayuda a identificarla en
/// clase). Se quita sola cuando ya hay foto.
class _AvisoFoto extends StatelessWidget {
  const _AvisoFoto({required this.alumna});
  final Alumna alumna;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: const Icon(Icons.photo_camera_outlined, color: AppColors.navy),
        title: Text('Añade la foto de ${alumna.nombreCorto}'),
        subtitle: const Text(
          'Ayuda al entrenador a conocerla. La ven solo tu familia, su '
          'entrenador y la dirección.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => cambiarFotoAlumna(context, alumna),
      ),
    );
  }
}

/// La familia pone o cambia la foto de su hija.
Future<void> cambiarFotoAlumna(BuildContext context, Alumna alumna) async {
  final repo = context.read<ClubRepository>();
  final r = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  final f = r?.files.single;
  if (f?.bytes == null) return;
  if (f!.size > 40 * 1024 * 1024) {
    if (context.mounted) {
      showAppSnackBar(context, 'La foto pesa demasiado (máx. 40 MB).',
          isError: true);
    }
    return;
  }
  try {
    await repo.actualizarAlumna(
      alumna.id,
      fotoNueva: f.bytes,
      fotoAnterior: alumna.fotoPath,
    );
    if (context.mounted) showAppSnackBar(context, 'Foto actualizada.');
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        '$e'.contains('No se pudo leer')
            ? 'No se pudo leer la imagen. Prueba con otra foto (JPG o PNG).'
            : 'No se pudo subir la foto. Inténtalo de nuevo.',
        isError: true,
      );
    }
  }
}
