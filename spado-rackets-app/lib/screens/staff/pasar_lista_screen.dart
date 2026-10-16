import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/asistencia.dart';
import '../../models/grupo.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/foto_alumna.dart';

/// Pase de lista de un grupo en una fecha.
///
/// Las faltas que la familia avisó por la app llegan ya marcadas como
/// justificadas. Volver a guardar el mismo día corrige, no duplica.
class PasarListaScreen extends StatefulWidget {
  const PasarListaScreen({super.key, required this.grupoId, this.fecha});

  final String grupoId;
  final String? fecha;

  @override
  State<PasarListaScreen> createState() => _PasarListaScreenState();
}

class _PasarListaScreenState extends State<PasarListaScreen> {
  late DateTime _fecha;
  final Map<String, EstadoAsistencia> _marcas = {};
  bool _cargadas = false;
  bool _guardando = false;

  late final ClubRepository _repo = context.read<ClubRepository>();
  late final Stream<List<Grupo>> _grupos = _repo.watchGrupos();
  late final Stream<List<Alumna>> _alumnas =
      _repo.watchAlumnasDeGrupos([widget.grupoId]);
  late Stream<List<Asistencia>> _sesion;
  late Stream<List<Ausencia>> _ausencias;

  @override
  void initState() {
    super.initState();
    _fecha = DateTime.tryParse(widget.fecha ?? '') ?? DateTime.now();
    _abrirSesion();
  }

  void _abrirSesion() {
    final clave = claveFecha(_fecha);
    _sesion = _repo.watchSesion(widget.grupoId, clave);
    _ausencias = _repo.watchAusenciasSesion(widget.grupoId, clave);
    _marcas.clear();
    _cargadas = false;
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
    );
    if (f == null) return;
    setState(() {
      _fecha = f;
      _abrirSesion();
    });
  }

  /// Marca o desmarca a UNA alumna y guarda al instante: al marcarla presente,
  /// su familia recibe el aviso de que está en el entrenamiento.
  Future<void> _marcar(Grupo grupo, Alumna alumna, bool presente) async {
    final anterior = _marcas[alumna.id];
    setState(() => _marcas[alumna.id] =
        presente ? EstadoAsistencia.presente : EstadoAsistencia.falta);
    try {
      final user = context.read<SessionController>().appUser!;
      await _repo.guardarLista(
        grupo: grupo,
        fecha: claveFecha(_fecha),
        alumnas: [alumna],
        marcas: {alumna.id: _marcas[alumna.id]!},
        quien: user,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (anterior == null) {
          _marcas.remove(alumna.id);
        } else {
          _marcas[alumna.id] = anterior;
        }
      });
      showAppSnackBar(
        context,
        'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.',
        isError: true,
      );
    }
  }

  /// Todas las alumnas sin marcar quedan como falta (o falta justificada si la
  /// familia avisó) y se cierra la lista.
  Future<void> _terminar(
    Grupo grupo,
    List<Alumna> alumnas,
    Map<String, Ausencia> avisos,
  ) async {
    final user = context.read<SessionController>().appUser!;
    final pendientes = alumnas
        .where((a) => _marcas[a.id] != EstadoAsistencia.presente)
        .toList();
    setState(() => _guardando = true);
    try {
      final marcas = {
        for (final a in pendientes)
          a.id: avisos.containsKey(a.id)
              ? EstadoAsistencia.justificada
              : EstadoAsistencia.falta,
      };
      if (pendientes.isNotEmpty) {
        await _repo.guardarLista(
          grupo: grupo,
          fecha: claveFecha(_fecha),
          alumnas: pendientes,
          marcas: marcas,
          quien: user,
        );
      }
      if (!mounted) return;
      showAppSnackBar(
        context,
        pendientes.isEmpty
            ? 'Lista guardada: asisten todas.'
            : 'Lista guardada. No han venido ${pendientes.length}.',
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamView<List<Grupo>>(
      stream: _grupos,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, grupos) {
        final grupo = grupos.where((g) => g.id == widget.grupoId).firstOrNull;
        if (grupo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pasar lista')),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Este grupo ya no existe',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(grupo.nombre)),
          body: StreamView<List<Alumna>>(
            stream: _alumnas,
            builder: (context, todas) {
              final alumnas = todas.where((a) => a.activa).toList();
              return StreamView<List<Asistencia>>(
                stream: _sesion,
                builder: (context, guardadas) => StreamView<List<Ausencia>>(
                  stream: _ausencias,
                  builder: (context, ausencias) =>
                      _lista(grupo, alumnas, guardadas, ausencias),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _lista(
    Grupo grupo,
    List<Alumna> alumnas,
    List<Asistencia> guardadas,
    List<Ausencia> ausencias,
  ) {
    final avisos = {for (final a in ausencias) a.alumnaId: a};
    if (!_cargadas) {
      // Primera vez: lo ya guardado.
      for (final g in guardadas) {
        _marcas[g.alumnaId] = g.estado;
      }
      _cargadas = true;
    }

    final presentes =
        alumnas.where((a) => _marcas[a.id] == EstadoAsistencia.presente).length;
    final yaGuardada = guardadas.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: PageBody(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event, color: AppColors.navy),
                  title: Text(capitalizar(fechaLargaFormat.format(_fecha))),
                  subtitle: Text(yaGuardada
                      ? 'Guardada por ${guardadas.first.marcadoPorNombre ?? 'el club'}'
                      : grupo.horarioTexto),
                  trailing: TextButton(
                    onPressed: _elegirFecha,
                    child: const Text('Cambiar'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatusChip(
                      label: '$presentes de ${alumnas.length} en la pista',
                      color: AppColors.success,
                      icon: Icons.check,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: alumnas.isEmpty
                        ? null
                        : () async {
                            final user =
                                context.read<SessionController>().appUser!;
                            setState(() {
                              for (final a in alumnas) {
                                _marcas[a.id] = EstadoAsistencia.presente;
                              }
                            });
                            try {
                              await _repo.guardarLista(
                                grupo: grupo,
                                fecha: claveFecha(_fecha),
                                alumnas: alumnas,
                                marcas: {
                                  for (final a in alumnas)
                                    a.id: EstadoAsistencia.presente,
                                },
                                quien: user,
                              );
                            } catch (_) {
                              if (mounted) {
                                showAppSnackBar(
                                  context,
                                  'No se pudo guardar. Inténtalo de nuevo.',
                                  isError: true,
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Todas presentes'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (alumnas.isEmpty)
                const EmptyState(
                  compacto: true,
                  icon: Icons.person_off_outlined,
                  title: 'Este grupo no tiene alumnas',
                  message: 'Dirección las da de alta desde "Alumnas".',
                )
              else
                CardList(
                  children: [
                    for (final a in alumnas)
                      _FilaAlumna(
                        alumna: a,
                        presente: _marcas[a.id] == EstadoAsistencia.presente,
                        aviso: avisos[a.id],
                        onChanged: (v) => _marcar(grupo, a, v),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Marca a cada alumna al llegar: su familia recibe el aviso '
                'al momento.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 728),
                child: FilledButton(
                  onPressed: _guardando || alumnas.isEmpty
                      ? null
                      : () => _terminar(grupo, alumnas, avisos),
                  child: Text(_guardando ? 'Guardando…' : 'Terminar lista'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaAlumna extends StatelessWidget {
  const _FilaAlumna({
    required this.alumna,
    required this.presente,
    required this.onChanged,
    this.aviso,
  });

  final Alumna alumna;
  final bool presente;
  final Ausencia? aviso;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: presente,
      label: '${alumna.nombre}, ${presente ? 'presente' : 'sin marcar'}',
      child: InkWell(
        onTap: () => onChanged(!presente),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              FotoAlumna(alumna, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alumna.nombre, style: t.titleSmall),
                    if (aviso != null)
                      Text(
                        'Aviso de la familia: ${aviso!.motivo.isEmpty ? 'no vendrá' : aviso!.motivo}',
                        style:
                            t.bodySmall?.copyWith(color: AppColors.warning),
                      ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: presente ? AppColors.success : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: presente ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  color: presente ? Colors.white : Colors.transparent,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
