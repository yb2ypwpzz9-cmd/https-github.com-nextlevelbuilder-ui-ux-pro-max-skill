import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Un hilo de mensajes.
class ConversacionScreen extends StatefulWidget {
  const ConversacionScreen({super.key, required this.conversacionId});
  final String conversacionId;

  @override
  State<ConversacionScreen> createState() => _ConversacionScreenState();
}

class _ConversacionScreenState extends State<ConversacionScreen> {
  final _texto = TextEditingController();
  EntradaDirectorio? _otro;

  late final ClubRepository _repo = context.read<ClubRepository>();
  late final AppUser _yo = context.read<SessionController>().appUser!;
  late final Stream<Conversacion?> _conv =
      _repo.watchConversacion(widget.conversacionId);
  late final Stream<List<Mensaje>> _mensajes =
      _repo.watchMensajes(widget.conversacionId);

  bool get _esDirecta => widget.conversacionId.startsWith('d_');

  @override
  void initState() {
    super.initState();
    _repo.marcarLeida(widget.conversacionId, _yo.uid);
    if (_esDirecta) _cargarOtro();
  }

  /// En una directa nueva todavía no hay documento: el nombre del otro sale
  /// del directorio, y con él se crea la conversación al primer mensaje.
  Future<void> _cargarOtro() async {
    final uids = widget.conversacionId.substring(2).split('_');
    final otroUid = uids.firstWhere((u) => u != _yo.uid, orElse: () => '');
    if (otroUid.isEmpty) return;
    final e = await _repo.entradaDirectorio(otroUid);
    if (mounted) setState(() => _otro = e);
  }

  @override
  void dispose() {
    // Al salir: lo que llegó mientras estaba abierta ya está leído.
    _repo.marcarLeida(widget.conversacionId, _yo.uid);
    _texto.dispose();
    super.dispose();
  }

  /// Envío optimista: el mensaje se pinta al instante desde la caché local y
  /// el servidor lo confirma después. Esperar la confirmación dejaba el botón
  /// girando mientras la red decidía.
  void _enviar({required bool conversacionExiste}) {
    final texto = _texto.text.trim();
    if (texto.isEmpty) return;
    _texto.clear();
    _repo
        .enviarMensaje(
      conversacionId: widget.conversacionId,
      autor: _yo,
      texto: texto,
      directaCon: _esDirecta ? _otro : null,
      conversacionExiste: conversacionExiste,
    )
        .catchError((Object _) {
      if (mounted) {
        _texto.text = texto;
        showAppSnackBar(
          context,
          'No se pudo enviar. Revisa tu conexión.',
          isError: true,
        );
      }
    });
  }

  Future<void> _opciones(Mensaje m) async {
    if (!_yo.role.isDireccion || m.oculto) return;
    final ok = await confirmar(
      context,
      titulo: 'Retirar mensaje',
      mensaje: 'Dejará de verse para todos. Queda guardado por si hay que '
          'explicar la decisión.',
      accion: 'Retirar',
      peligrosa: true,
    );
    if (ok) await _repo.ocultarMensaje(widget.conversacionId, m.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Conversacion?>(
      stream: _conv,
      builder: (context, snap) {
        final conv = snap.data;
        final titulo = conv?.nombrePara(_yo.uid) ??
            (widget.conversacionId == Conversacion.idAvisos
                ? 'Avisos del club'
                : _otro?.nombre ?? 'Conversación');
        final puedeEscribir = conv == null
            ? widget.conversacionId != Conversacion.idAvisos ||
                _yo.role.esDelClub
            : conv.puedeEscribir(_yo.role);
        final subtitulo = switch (conv?.tipo) {
          TipoConversacion.avisos => 'Publican Dirección y staff',
          TipoConversacion.grupo =>
            '${conv!.participantes.length} participantes',
          _ => _otro?.rol.label,
        };

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, overflow: TextOverflow.ellipsis),
                if (subtitulo != null)
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamView<List<Mensaje>>(
                  stream: _mensajes,
                  builder: (context, mensajes) {
                    if (mensajes.isEmpty) {
                      return EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Aún no hay mensajes',
                        message: puedeEscribir
                            ? 'Escribe el primero abajo.'
                            : 'Cuando el club publique un aviso, lo verás '
                                'aquí.',
                      );
                    }
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: mensajes.length,
                          itemBuilder: (context, i) {
                            final m = mensajes[i];
                            final anterior =
                                i + 1 < mensajes.length ? mensajes[i + 1] : null;
                            final nuevoDia = anterior == null ||
                                !_mismoDia(anterior.creadoEn, m.creadoEn);
                            return Column(
                              children: [
                                if (nuevoDia) _SeparadorDia(m.creadoEn),
                                _Burbuja(
                                  m: m,
                                  mia: m.autorUid == _yo.uid,
                                  mostrarAutor:
                                      conv?.tipo != TipoConversacion.directa,
                                  onLongPress: () => _opciones(m),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (puedeEscribir)
                _Compositor(
                  controller: _texto,
                  enviando: false,
                  onEnviar: () =>
                      _enviar(conversacionExiste: conv != null || !_esDirecta),
                  // Una directa nueva necesita saber si ya existe (el
                  // documento ya ha llegado) y el directorio para crearse.
                  listo: !_esDirecta ||
                      conv != null ||
                      (_otro != null &&
                          snap.connectionState != ConnectionState.waiting),
                )
              else
                const SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Sólo Dirección y staff publican avisos. Para una '
                      'consulta, escribe a Dirección desde "Mensajes".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static bool _mismoDia(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}

class _SeparadorDia extends StatelessWidget {
  const _SeparadorDia(this.fecha);
  final DateTime? fecha;

  @override
  Widget build(BuildContext context) {
    if (fecha == null) return const SizedBox.shrink();
    final hoy = DateTime.now();
    final esHoy = fecha!.year == hoy.year &&
        fecha!.month == hoy.month &&
        fecha!.day == hoy.day;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            esHoy ? 'Hoy' : capitalizar(fechaCortaFormat.format(fecha!)),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.m,
    required this.mia,
    required this.mostrarAutor,
    required this.onLongPress,
  });

  final Mensaje m;
  final bool mia;
  final bool mostrarAutor;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final fondo = mia ? AppColors.navy : AppColors.surface;
    final texto = mia ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: mia ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78 > 520
                ? 520
                : MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: fondo,
            border: mia ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mia ? 14 : 4),
              bottomRight: Radius.circular(mia ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mia && mostrarAutor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    m.autorRol.esDelClub
                        ? '${m.autorNombre} · ${m.autorRol.label}'
                        : m.autorNombre,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: m.autorRol.esDelClub
                          ? AppColors.navy
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              Text(
                m.oculto ? 'Mensaje retirado por Dirección' : m.texto,
                style: TextStyle(
                  color: m.oculto ? texto.withValues(alpha: 0.6) : texto,
                  fontStyle: m.oculto ? FontStyle.italic : FontStyle.normal,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  m.creadoEn == null ? '' : horaFormat.format(m.creadoEn!),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: texto.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Compositor extends StatelessWidget {
  const _Compositor({
    required this.controller,
    required this.enviando,
    required this.onEnviar,
    required this.listo,
  });

  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onEnviar;
  final bool listo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: Mensaje.maxCaracteres,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                        counterText: '',
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide(color: AppColors.navy),
                        ),
                      ),
                      onSubmitted: (_) => onEnviar(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(46, 46),
                    ),
                    onPressed: enviando || !listo ? null : onEnviar,
                    icon: enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
