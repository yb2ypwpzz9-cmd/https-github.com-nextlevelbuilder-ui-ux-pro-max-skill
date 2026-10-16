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

  Future<void> _guardar(Grupo grupo, List<Alumna> alumnas) async {
    final faltan = alumnas.where((a) => _marcas[a.id] == null).length;
    if (faltan > 0) {
      showAppSnackBar(
        context,
        faltan == 1
            ? 'Falta marcar a 1 alumna.'
            : 'Faltan $faltan alumnas por marcar.',
        isError: true,
      );
      return;
    }
    final user = context.read<SessionController>().appUser!;
    setState(() => _guardando = true);
    try {
      await _repo.guardarLista(
        grupo: grupo,
        fecha: claveFecha(_fecha),
        alumnas: alumnas,
        marcas: _marcas,
        quien: user,
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Lista guardada.');
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
      // Primera vez: lo ya guardado, y si no, las faltas avisadas.
      for (final g in guardadas) {
        _marcas[g.alumnaId] = g.estado;
      }
      for (final a in alumnas) {
        if (_marcas[a.id] == null && avisos.containsKey(a.id)) {
          _marcas[a.id] = EstadoAsistencia.justificada;
        }
      }
      _cargadas = true;
    }

    final t = Theme.of(context).textTheme;
    final cuenta = {
      for (final e in EstadoAsistencia.values)
        e: _marcas.entries
            .where((m) => m.value == e && alumnas.any((a) => a.id == m.key))
            .length,
    };
    final marcadas = alumnas.where((a) => _marcas[a.id] != null).length;
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
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusChip(
                          label: '${cuenta[EstadoAsistencia.presente]} asisten',
                          color: AppColors.success,
                        ),
                        StatusChip(
                          label: '${cuenta[EstadoAsistencia.falta]} faltas',
                          color: AppColors.danger,
                        ),
                        StatusChip(
                          label:
                              '${cuenta[EstadoAsistencia.justificada]} justificadas',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      for (final a in alumnas) {
                        if (_marcas[a.id] != EstadoAsistencia.justificada) {
                          _marcas[a.id] = EstadoAsistencia.presente;
                        }
                      }
                    }),
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
                        estado: _marcas[a.id],
                        aviso: avisos[a.id],
                        onChanged: (e) => setState(() => _marcas[a.id] = e),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'P = asistió · F = falta · J = falta justificada',
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                      : () => _guardar(grupo, alumnas),
                  child: Text(_guardando
                      ? 'Guardando…'
                      : '${yaGuardada ? 'Actualizar' : 'Guardar'} lista '
                          '($marcadas/${alumnas.length})'),
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
    required this.estado,
    required this.onChanged,
    this.aviso,
  });

  final Alumna alumna;
  final EstadoAsistencia? estado;
  final Ausencia? aviso;
  final ValueChanged<EstadoAsistencia> onChanged;

  static const _colores = {
    EstadoAsistencia.presente: AppColors.success,
    EstadoAsistencia.falta: AppColors.danger,
    EstadoAsistencia.justificada: AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          FotoAlumna(alumna, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alumna.nombre, style: t.titleSmall),
                if (aviso != null)
                  Text(
                    'Aviso de la familia: ${aviso!.motivo.isEmpty ? 'sin motivo' : aviso!.motivo}',
                    style: t.bodySmall?.copyWith(color: AppColors.warning),
                  ),
              ],
            ),
          ),
          for (final e in EstadoAsistencia.values)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Semantics(
                button: true,
                selected: estado == e,
                label: '${e.label} ${alumna.nombre}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: estado == e ? _colores[e] : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: estado == e ? _colores[e]! : AppColors.border,
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      e.letra,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: estado == e
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
