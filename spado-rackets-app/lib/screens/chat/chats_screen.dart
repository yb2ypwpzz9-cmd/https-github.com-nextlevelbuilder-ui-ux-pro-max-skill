import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../app_shell.dart';

/// Bandeja de mensajes: avisos del club, chats de grupo y conversaciones
/// privadas. Sustituye a los grupos de WhatsApp.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().appUser!;
    return Scaffold(
      appBar: const TabAppBar(title: 'Mensajes'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/chat/nueva'),
        icon: const Icon(Icons.edit_outlined),
        label: Text(user.role.isFamilia ? 'Escribir al club' : 'Nuevo mensaje'),
      ),
      body: StreamView<List<Conversacion>>(
        stream: context.read<ClubRepository>().watchConversaciones(user.uid),
        builder: (context, convs) {
          if (convs.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'Todavía no hay conversaciones',
              message: 'Aquí aparecerán los avisos del club y el chat de tu '
                  'grupo.',
            );
          }
          return PageBody(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              CardList(
                children: [
                  for (final c in convs) _FilaConversacion(c: c, yo: user),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                user.role.isFamilia
                    ? 'Los avisos los publica el club. Para una consulta '
                        'privada, escribe directamente a Dirección o a tu '
                        'entrenador.'
                    : 'Los avisos llegan a todas las familias. El chat de '
                        'cada grupo, sólo a las familias de ese grupo.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilaConversacion extends StatelessWidget {
  const _FilaConversacion({required this.c, required this.yo});
  final Conversacion c;
  final AppUser yo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sinLeer = c.sinLeerPara(yo.uid);
    final nombre = c.nombrePara(yo.uid);
    final (icono, color) = switch (c.tipo) {
      TipoConversacion.avisos => (Icons.campaign_outlined, AppColors.danger),
      TipoConversacion.grupo => (Icons.groups_outlined, AppColors.navy),
      TipoConversacion.directa => (Icons.person_outline, AppColors.navySoft),
    };
    final ahora = DateTime.now();
    final f = c.ultimoMensajeEn;
    final cuando = f == null
        ? ''
        : (f.year == ahora.year && f.month == ahora.month && f.day == ahora.day)
            ? horaFormat.format(f)
            : fechaFormat.format(f);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              nombre,
              style: t.titleSmall?.copyWith(
                fontWeight: sinLeer > 0 ? FontWeight.w800 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(cuando, style: t.labelSmall),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              c.ultimoMensaje.isEmpty
                  ? 'Sin mensajes todavía'
                  : '${c.ultimoAutor.split(' ').first}: ${c.ultimoMensaje}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sinLeer > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$sinLeer',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      onTap: () => context.push('/chat/${c.id}'),
    );
  }
}
