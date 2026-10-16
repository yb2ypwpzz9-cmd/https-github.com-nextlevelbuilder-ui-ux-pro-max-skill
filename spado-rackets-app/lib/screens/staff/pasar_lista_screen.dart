import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/app_user.dart';
import '../../models/asistencia.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/foto_alumna.dart';

/// Pase de lista de un día: aparecen las personas que tienen clase ese día de
/// la semana (cada una tiene su propio horario). Al marcar a alguien, su
/// familia recibe el aviso de que ya está en el entrenamiento.
class PasarListaScreen extends StatefulWidget {
  const PasarListaScreen({super.key, this.fecha});

  final String? fecha;

  @override
  State<PasarListaScreen> createState() => _PasarListaScreenState();
}

class _PasarListaScreenState extends State<PasarListaScreen> {
  late DateTime _fecha;
  final Map<String, EstadoAsistencia> _marcas = {};
  bool _cargadas = false;
  bool _guardando = false;
  bool _verTodos = false;

  late final ClubRepository _repo = context.read<ClubRepository>();
  late final AppUser _yo = context.read<SessionController>().appUser!;
  late final Stream<List<Alumna>> _alumnas = _yo.role.isDireccion
      ? _repo.watchTodasLasAlumnas()
      : _repo.watchAlumnasDeGrupos(_yo.grupos);
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
    final grupos = _yo.role.isDireccion ? null : _yo.grupos;
    _sesion = _repo.watchAsistenciaDia(clave, grupos: grupos);
    _ausencias = _repo.watchAusenciasDia(clave, grupos: grupos);
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

  /// Marca o desmarca a UNA persona y guarda al instante: al marcarla presente,
  /// su familia recibe el aviso de que está en el entrenamiento.
  Future<void> _marcar(Alumna alumna, bool presente) async {
    final anterior = _marcas[alumna.id];
    setState(() => _marcas[alumna.id] =
        presente ? EstadoAsistencia.presente : EstadoAsistencia.falta);
    try {
      await _repo.guardarLista(
        fecha: claveFecha(_fecha),
        alumnas: [alumna],
        marcas: {alumna.id: _marcas[alumna.id]!},
        quien: _yo,
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

  /// Quien no tiene check queda como falta (o falta justificada si la familia
  /// avisó) y se cierra la lista.
  Future<void> _terminar(
    List<Alumna> alumnas,
    Map<String, Ausencia> avisos,
  ) async {
    final pendientes = alumnas
        .where((a) => _marcas[a.id] != EstadoAsistencia.presente)
        .toList();
    setState(() => _guardando = true);
    try {
      if (pendientes.isNotEmpty) {
        await _repo.guardarLista(
          fecha: claveFecha(_fecha),
          alumnas: pendientes,
          marcas: {
            for (final a in pendientes)
              a.id: avisos.containsKey(a.id)
                  ? EstadoAsistencia.justificada
                  : EstadoAsistencia.falta,
          },
          quien: _yo,
        );
      }
      if (!mounted) return;
      showAppSnackBar(
        context,
        pendientes.isEmpty
            ? 'Lista guardada: no falta nadie.'
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
    return Scaffold(
      appBar: AppBar(title: const Text('Pasar lista')),
      body: StreamView<List<Alumna>>(
        stream: _alumnas,
        builder: (context, todas) => StreamView<List<Asistencia>>(
          streamKey: claveFecha(_fecha),
          stream: _sesion,
          builder: (context, guardadas) => StreamView<List<Ausencia>>(
            streamKey: claveFecha(_fecha),
            stream: _ausencias,
            builder: (context, ausencias) =>
                _lista(todas.where((a) => a.activa).toList(), guardadas, ausencias),
          ),
        ),
      ),
    );
  }

  Widget _lista(
    List<Alumna> activas,
    List<Asistencia> guardadas,
    List<Ausencia> ausencias,
  ) {
    final avisos = {for (final a in ausencias) a.alumnaId: a};
    if (!_cargadas) {
      for (final g in guardadas) {
        _marcas[g.alumnaId] = g.estado;
      }
      _cargadas = true;
    }

    // Quien tiene clase ese día, más quien ya tiene marca aunque su horario
    // no coincida (por ejemplo, una clase recuperada).
    final alumnas = activas
        .where((a) =>
            _verTodos || a.tieneClaseEl(_fecha) || _marcas.containsKey(a.id))
        .toList()
      ..sort((a, b) {
        final c = a.horaInicio.compareTo(b.horaInicio);
        return c != 0 ? c : a.nombre.compareTo(b.nombre);
      });

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
                      : '${alumnas.length} ${alumnas.length == 1 ? 'persona tiene' : 'personas tienen'} clase'),
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
                            setState(() {
                              for (final a in alumnas) {
                                _marcas[a.id] = EstadoAsistencia.presente;
                              }
                            });
                            try {
                              await _repo.guardarLista(
                                fecha: claveFecha(_fecha),
                                alumnas: alumnas,
                                marcas: {
                                  for (final a in alumnas)
                                    a.id: EstadoAsistencia.presente,
                                },
                                quien: _yo,
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
                    label: const Text('Todos presentes'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Mostrar a todo el alumnado'),
                subtitle: const Text('Para una clase de recuperación o extra'),
                value: _verTodos,
                onChanged: (v) => setState(() => _verTodos = v),
              ),
              if (alumnas.isEmpty)
                const EmptyState(
                  compacto: true,
                  icon: Icons.event_available_outlined,
                  title: 'Nadie tiene clase este día',
                  message: 'Los días y la hora de cada persona los pone '
                      'Dirección en su ficha.',
                )
              else
                CardList(
                  children: [
                    for (final a in alumnas)
                      _FilaAlumna(
                        alumna: a,
                        presente: _marcas[a.id] == EstadoAsistencia.presente,
                        aviso: avisos[a.id],
                        onChanged: (v) => _marcar(a, v),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Marca a cada persona al llegar: su familia recibe el aviso '
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
                      : () => _terminar(alumnas, avisos),
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
                    if (alumna.horaInicio.isNotEmpty)
                      Text(alumna.horaInicio, style: t.bodySmall),
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
