import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/club_config.dart';
import '../../models/alumna.dart';
import '../../models/grupo.dart';
import '../../models/pago.dart' show formatoImporte;
import '../../services/club_repository.dart';
import '../../services/descarga.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/contacto.dart';
import '../../widgets/foto_alumna.dart';
import '../../widgets/horario_alumna.dart';
import '../../widgets/invitacion.dart';

/// Alumnado, con el horario y la cuota de cada persona y el código que se
/// entrega a su familia.
class AlumnasScreen extends StatelessWidget {
  const AlumnasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubRepository>();
    return StreamView<List<Grupo>>(
      stream: repo.watchGrupos(),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, grupos) => Scaffold(
        appBar: AppBar(title: const Text('Alumnado y códigos')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          onPressed: () => _editar(context, grupos, null),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Nuevo alumno/a'),
        ),
        body: StreamView<List<Alumna>>(
          stream: repo.watchTodasLasAlumnas(),
          builder: (context, alumnas) => StreamView<List<CodigoVinculacion>>(
            stream: repo.watchCodigos(),
            builder: (context, codigos) {
              final codigoDe = {for (final c in codigos) c.alumnaId: c};
              final sinVincular =
                  alumnas.where((a) => a.activa && !a.vinculada).length;
              return PageBody(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  BotonExcel(
                    onPressed: () => descargarExcel('alumnado', {
                      'Alumnado': [
                        [
                          'Nombre',
                          'Tipo',
                          'Edad',
                          'Fecha de nacimiento',
                          'Nivel',
                          'Días de clase',
                          'Hora',
                          'Cuota mensual (US\$)',
                          'Contacto',
                          'Teléfono',
                          'Email de la familia',
                          'Familia con cuenta',
                          'Activo',
                          'Código',
                        ],
                        for (final a in alumnas)
                          [
                            a.nombre,
                            a.tipo?.label,
                            a.edad,
                            a.fechaNacimiento == null
                                ? null
                                : '${a.fechaNacimiento!.year}-${a.fechaNacimiento!.month.toString().padLeft(2, '0')}-${a.fechaNacimiento!.day.toString().padLeft(2, '0')}',
                            a.nivel?.label,
                            a.dias
                                .map((d) => Grupo.nombresDias[d - 1])
                                .join(' '),
                            a.dias.isEmpty ? '' : a.horarioTexto,
                            a.cuotaMensual,
                            a.contactoNombre,
                            a.contactoTelefono,
                            a.emailFamilia,
                            a.vinculada ? 'Sí' : 'No',
                            a.activa ? 'Sí' : 'No',
                            codigoDe[a.id]?.codigo,
                          ],
                      ],
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  InlineNotice(
                    message: sinVincular == 0
                        ? 'Todas las familias tienen cuenta.'
                        : '$sinVincular ${sinVincular == 1 ? 'ficha' : 'fichas'} '
                            'sin cuenta de familia. Entrega a cada familia su '
                            'código: se registra con él en la app.',
                    icon: sinVincular == 0
                        ? Icons.check_circle_outline
                        : Icons.key_outlined,
                    color:
                        sinVincular == 0 ? AppColors.success : AppColors.info,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ListaGrupo(
                    alumnas: alumnas,
                    codigoDe: codigoDe,
                    onEditar: (a) => _editar(context, grupos, a),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _editar(
    BuildContext context,
    List<Grupo> grupos,
    Alumna? alumna,
  ) async {
    final raiz = context;
    final repo = context.read<ClubRepository>();
    final nombre = TextEditingController(text: alumna?.nombre ?? '');
    final email = TextEditingController(text: alumna?.emailFamilia ?? '');
    final contactoNombre =
        TextEditingController(text: alumna?.contactoNombre ?? '');
    final contactoTelefono =
        TextEditingController(text: alumna?.contactoTelefono ?? '');

    // Un alumno de antes (con grupo) hereda al editarlo el horario y la cuota
    // de su grupo, para no empezar de cero.
    final heredado = alumna == null || alumna.dias.isNotEmpty
        ? null
        : grupos.where((g) => g.id == alumna.grupo).firstOrNull;
    var activa = alumna?.activa ?? true;
    DateTime? nacimiento = alumna?.fechaNacimiento;
    NivelTenis? nivel = alumna?.nivel;
    TipoJugador? tipo = alumna?.tipo;
    final dias = <int>{...?alumna?.dias, ...?heredado?.dias};
    final horas = <int, TimeOfDay>{
      if (alumna != null) ...horasDe(alumna, porDefecto: heredado?.horaInicio),
      if (alumna == null || alumna.dias.isEmpty)
        for (final d in dias)
          if (_parseHora(heredado?.horaInicio) case final h?) d: h,
    };
    var duracion = alumna?.duracionMinutos ?? heredado?.duracionMinutos ?? 60;
    final cuota = TextEditingController(
      text: () {
        final v = (alumna != null && alumna.cuotaMensual > 0)
            ? alumna.cuotaMensual
            : (heredado?.cuotaMensual ?? 0);
        return v == 0 ? '' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
      }(),
    );
    Uint8List? fotoNueva;
    var quitarFoto = false;

    final guardar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            pieHoja(context),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  alumna == null ? 'Nuevo alumno o alumna' : 'Editar ficha',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nombre,
                  autofocus: alumna == null,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Nombre y apellidos'),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<TipoJugador>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: [
                    for (final t in TipoJugador.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {if (tipo != null) tipo!},
                  onSelectionChanged: (s) =>
                      setSheet(() => tipo = s.isEmpty ? null : s.first),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (fotoNueva != null)
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: MemoryImage(fotoNueva!),
                      )
                    else if (alumna != null && !quitarFoto)
                      FotoAlumna(alumna, size: 60)
                    else
                      const Avatar('+', size: 60),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44)),
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 18),
                            label: Text(fotoNueva != null ||
                                    (alumna?.fotoPath != null && !quitarFoto)
                                ? 'Cambiar foto'
                                : 'Añadir foto'),
                            onPressed: () async {
                              final r = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              final f = r?.files.single;
                              if (f?.bytes == null) return;
                              if (f!.size > 40 * 1024 * 1024) {
                                if (context.mounted) {
                                  showAppSnackBar(context,
                                      'La foto pesa demasiado (máx. 40 MB).',
                                      isError: true);
                                }
                                return;
                              }
                              setSheet(() {
                                fotoNueva = f.bytes;
                                quitarFoto = false;
                              });
                            },
                          ),
                          if (fotoNueva != null ||
                              (alumna?.fotoPath != null && !quitarFoto))
                            TextButton(
                              onPressed: () => setSheet(() {
                                fotoNueva = null;
                                quitarFoto = true;
                              }),
                              child: const Text('Quitar'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cake_outlined, size: 18),
                  label: Text(nacimiento == null
                      ? 'Fecha de nacimiento'
                      : 'Nació el ${nacimiento!.day.toString().padLeft(2, '0')}/'
                          '${nacimiento!.month.toString().padLeft(2, '0')}/'
                          '${nacimiento!.year}'),
                  onPressed: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate:
                          nacimiento ?? DateTime(DateTime.now().year - 9),
                      firstDate: DateTime(DateTime.now().year - 90),
                      lastDate: DateTime.now(),
                    );
                    if (f != null) setSheet(() => nacimiento = f);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<NivelTenis?>(
                  initialValue: nivel,
                  decoration:
                      const InputDecoration(labelText: 'Nivel de tenis'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Sin definir')),
                    for (final n in NivelTenis.values)
                      DropdownMenuItem(value: n, child: Text(n.label)),
                  ],
                  onChanged: (v) => setSheet(() => nivel = v),
                ),
                const SectionHeader('Clases'),
                EditorHorarioSemanal(
                  dias: dias,
                  horas: horas,
                  onCambio: () => setSheet(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: duracion,
                  decoration: const InputDecoration(labelText: 'Duración'),
                  items: const [
                    DropdownMenuItem(value: 45, child: Text('45 min')),
                    DropdownMenuItem(value: 60, child: Text('1 h')),
                    DropdownMenuItem(value: 90, child: Text('1 h 30')),
                    DropdownMenuItem(value: 120, child: Text('2 h')),
                  ],
                  onChanged: (v) => setSheet(() => duracion = v ?? 60),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: cuota,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cuota mensual',
                    prefixText: 'US\$ ',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader('Contacto'),
                TextField(
                  controller: contactoNombre,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la persona de contacto (opcional)',
                    helperText: 'Madre, padre, tutor o la propia persona',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: contactoTelefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de contacto (opcional)',
                    hintText: '809 000 0000',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: alumna?.vinculada != true,
                  decoration: const InputDecoration(
                    labelText: 'Email de la familia (opcional)',
                    helperText: 'Si lo pones, sólo ese correo podrá '
                        'registrarse con el código de esta ficha.',
                    helperMaxLines: 2,
                  ),
                ),
                if (alumna != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    subtitle: const Text(
                      'Si se da de baja, deja de salir en las listas y no se '
                      'le generan cuotas.',
                    ),
                    value: activa,
                    onChanged: (v) => setSheet(() => activa = v),
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                      alumna == null ? 'Crear y generar código' : 'Guardar'),
                ),
                if (alumna != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar ficha'),
                    onPressed: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Eliminar a ${alumna.nombre}',
                        mensaje: 'Se borran su ficha, su código y sus cuotas '
                            'sin pagar. Las cuotas ya pagadas y la asistencia '
                            'se conservan. Si solo deja el club, mejor márcalo '
                            'como no activo.',
                        accion: 'Eliminar',
                        peligrosa: true,
                      );
                      if (!ok) return;
                      try {
                        await repo.eliminarAlumna(alumna.id,
                            fotoPath: alumna.fotoPath);
                        if (context.mounted) Navigator.pop(context, false);
                        if (raiz.mounted) {
                          showAppSnackBar(raiz, 'Ficha eliminada.');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          showAppSnackBar(context, 'No se pudo eliminar.',
                              isError: true);
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (guardar != true || nombre.text.trim().length < 2) return;

    final importe =
        double.tryParse(cuota.text.trim().replaceAll(',', '.')) ?? 0;
    final listaDias = dias.toList()..sort();
    final horaTexto = horaPrincipal(dias, horas);
    final horasPorDia = horasATextos(dias, horas);

    try {
      if (alumna == null) {
        final codigo = await repo.crearAlumna(
          nombre: nombre.text,
          emailFamilia: email.text,
          fechaNacimiento: nacimiento,
          nivel: nivel,
          tipo: tipo,
          dias: listaDias,
          horaInicio: horaTexto,
          horarios: horasPorDia,
          duracionMinutos: duracion,
          cuotaMensual: importe,
          contactoNombre: contactoNombre.text,
          contactoTelefono: contactoTelefono.text,
          foto: fotoNueva,
        );
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ficha creada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Entrega este código a la familia para que se '
                      'registre en la app:'),
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    codigo,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: codigo)),
                  child: const Text('Copiar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hecho'),
                ),
              ],
            ),
          );
        }
      } else {
        // Una ficha antigua pasa al grupo interno único.
        String? nuevoGrupo;
        if (alumna.grupo != ClubConfig.grupoGeneral) {
          await repo.asegurarGrupoGeneral();
          nuevoGrupo = ClubConfig.grupoGeneral;
        }
        await repo.actualizarAlumna(
          alumna.id,
          nombre: nombre.text,
          grupo: nuevoGrupo,
          activa: activa,
          emailFamilia: alumna.vinculada ? null : email.text,
          fechaNacimiento: nacimiento,
          quitarFecha: nacimiento == null && alumna.fechaNacimiento != null,
          nivel: nivel,
          quitarNivel: nivel == null && alumna.nivel != null,
          tipo: tipo,
          dias: listaDias,
          horaInicio: horaTexto,
          horarios: horasPorDia,
          duracionMinutos: duracion,
          cuotaMensual: importe,
          contactoNombre: contactoNombre.text,
          contactoTelefono: contactoTelefono.text,
          fotoNueva: fotoNueva,
          fotoAnterior: alumna.fotoPath,
          quitarFoto: quitarFoto,
        );
        if (context.mounted) showAppSnackBar(context, 'Guardado.');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo guardar.', isError: true);
      }
    }
  }

  static TimeOfDay? _parseHora(String? h) {
    final p = (h ?? '').split(':');
    if (p.length != 2) return null;
    final hh = int.tryParse(p[0]);
    final mm = int.tryParse(p[1]);
    if (hh == null || mm == null) return null;
    return TimeOfDay(hour: hh, minute: mm);
  }
}

class _ListaGrupo extends StatelessWidget {
  const _ListaGrupo({
    required this.alumnas,
    required this.codigoDe,
    required this.onEditar,
  });

  final List<Alumna> alumnas;
  final Map<String, CodigoVinculacion> codigoDe;
  final ValueChanged<Alumna> onEditar;

  @override
  Widget build(BuildContext context) {
    if (alumnas.isEmpty) {
      return Text('Sin alumnado.',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return CardList(
      children: [
        for (final a in alumnas)
          ListTile(
            leading: FotoAlumna(a),
            title: Text(
              a.nombre,
              style: a.activa
                  ? null
                  : const TextStyle(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
            ),
            subtitle: a.vinculada
                ? Text([
                    a.horarioTexto,
                    if (a.contactoNombre != null) a.contactoNombre!,
                    if (a.cuotaMensual > 0)
                      formatoImporte(
                          a.cuotaMensual, ClubConfig.monedaPorDefecto),
                    if (a.edad != null) '${a.edad} años',
                    if (a.nivel != null) a.nivel!.label,
                  ].join(' · '))
                : codigoDe[a.id] == null
                    ? const Text('Sin código')
                    : Text.rich(TextSpan(children: [
                        if (a.emailFamilia != null)
                          TextSpan(text: '${a.emailFamilia} · '),
                        const TextSpan(text: 'Código: '),
                        TextSpan(
                          text: codigoDe[a.id]!.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.navy,
                          ),
                        ),
                      ])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (a.contactoTelefono != null)
                  BotonesContacto(a.contactoTelefono!),
                if (!a.activa)
                  const StatusChip(
                    label: 'Baja',
                    color: AppColors.textSecondary,
                  )
                else if (a.vinculada)
                  const StatusChip(
                    label: 'Vinculada',
                    color: AppColors.success,
                    icon: Icons.link,
                  )
                else if (codigoDe[a.id] != null) ...[
                  IconButton(
                    tooltip: 'Enviar invitación',
                    icon: const Icon(Icons.send_outlined,
                        size: 19, color: AppColors.navy),
                    onPressed: () =>
                        mostrarInvitacion(context, a, codigoDe[a.id]!.codigo),
                  ),
                ],
              ],
            ),
            onTap: () => onEditar(a),
          ),
      ],
    );
  }
}
