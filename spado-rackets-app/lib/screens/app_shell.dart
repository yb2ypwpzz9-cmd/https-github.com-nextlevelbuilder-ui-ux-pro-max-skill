import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'chat/chats_screen.dart';
import 'direccion/direccion_home_screen.dart';
import 'direccion/fichajes_screen.dart';
import 'direccion/pagos_direccion_screen.dart';
import 'familia/familia_home_screen.dart';
import 'familia/pagos_familia_screen.dart';
import 'shared/mas_screen.dart';
import 'staff/staff_home_screen.dart';
import 'staff/staff_grupos_screen.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.builder,
      {this.esChat = false});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
  final bool esChat;
}

/// Contenedor tras el login: cada perfil ve sus propias pestañas.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static final _chat = _Tab('Mensajes', Icons.forum_outlined, Icons.forum,
      () => const ChatsScreen(),
      esChat: true);
  static final _mas =
      _Tab('Más', Icons.menu, Icons.menu, () => const MasScreen());

  List<_Tab> _tabsFor(UserRole role) => switch (role) {
        UserRole.familia => [
            _Tab('Inicio', Icons.home_outlined, Icons.home,
                () => const FamiliaHomeScreen()),
            _Tab('Pagos', Icons.receipt_long_outlined, Icons.receipt_long,
                () => const PagosFamiliaScreen()),
            _chat,
            _mas,
          ],
        UserRole.staff => [
            _Tab('Hoy', Icons.today_outlined, Icons.today,
                () => const StaffHomeScreen()),
            _Tab('Grupos', Icons.groups_outlined, Icons.groups,
                () => const StaffGruposScreen()),
            _chat,
            _mas,
          ],
        UserRole.direccion => [
            _Tab('Panel', Icons.space_dashboard_outlined,
                Icons.space_dashboard, () => const DireccionHomeScreen()),
            _Tab('Fichajes', Icons.badge_outlined, Icons.badge,
                () => const FichajesScreen()),
            _Tab('Pagos', Icons.receipt_long_outlined, Icons.receipt_long,
                () => const PagosDireccionScreen()),
            _chat,
            _mas,
          ],
      };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.appUser;

    if (session.loading) {
      return const Scaffold(body: LoadingView(message: 'Cargando tu perfil…'));
    }

    if (user == null) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Tu cuenta no está configurada',
          message: 'Tu usuario existe pero el club todavía no ha terminado de '
              'darte de alta. Contacta con Dirección.',
          action: OutlinedButton.icon(
            onPressed: () => context.read<SessionController>().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ),
      );
    }

    final tabs = _tabsFor(user.role);
    final index = _index.clamp(0, tabs.length - 1);

    return Provider<IrATab>.value(
      value: IrATab((label) {
        final i = tabs.indexWhere((t) => t.label == label);
        if (i >= 0) setState(() => _index = i);
      }),
      child: Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.builder()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.esChat
                  ? _IconoConAviso(icono: t.icon, uid: user.uid)
                  : Icon(t.icon),
              selectedIcon: t.esChat
                  ? _IconoConAviso(icono: t.selectedIcon, uid: user.uid)
                  : Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
      ),
    );
  }
}

/// Para que una pantalla lleve a otra pestaña ("Ver pagos" desde Inicio).
class IrATab {
  const IrATab(this._ir);
  final void Function(String label) _ir;
  void call(String label) => _ir(label);
}

class _IconoConAviso extends StatelessWidget {
  const _IconoConAviso({required this.icono, required this.uid});
  final IconData icono;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: context.read<ClubRepository>().watchSinLeer(uid),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        if (n == 0) return Icon(icono);
        return Badge(
          label: Text(n > 9 ? '9+' : '$n'),
          backgroundColor: AppColors.danger,
          textColor: Colors.white,
          child: Icon(icono),
        );
      },
    );
  }
}

/// Cabecera común de las pestañas: emblema, título y saludo.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: AppSpacing.md,
      title: Row(
        children: [
          Image.asset('assets/images/emblema_blanco.png', width: 26, height: 26),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: actions,
    );
  }
}
