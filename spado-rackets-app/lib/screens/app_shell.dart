import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/club_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../config/textos_legales.dart';
import 'auth/pasos_obligatorios.dart';
import 'auth/verificar_correo_screen.dart';
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
  // Pestañas ya visitadas: las demás no se construyen (ni abren sus
  // consultas a Firestore) hasta que se pulsan. Acelera el arranque en móvil.
  final Set<int> _visitadas = {0};

  static final _chat = _Tab(
      'Mensajes', Icons.forum_outlined, Icons.forum, () => const ChatsScreen(),
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
            _Tab('Alumnado', Icons.groups_outlined, Icons.groups,
                () => const StaffGruposScreen()),
            _chat,
            _mas,
          ],
        UserRole.direccion => [
            _Tab('Panel', Icons.space_dashboard_outlined, Icons.space_dashboard,
                () => const DireccionHomeScreen()),
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
      return const Scaffold(body: _CargandoPerfil());
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

    if (session.necesitaVerificarCorreo) {
      return const VerificarCorreoScreen();
    }

    if (user.debeCambiarPassword) {
      return const CambiarPasswordObligatorioScreen();
    }
    if (user.role.isStaff &&
        user.avisoUbicacionVersion != TextosLegales.avisoStaffVersion) {
      return const AvisoUbicacionScreen();
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= 900;
    final tabs = _tabsFor(user.role);
    final index = _index.clamp(0, tabs.length - 1);

    return Provider<IrATab>.value(
      value: IrATab((label) {
        final i = tabs.indexWhere((t) => t.label == label);
        if (i >= 0) {
          setState(() {
            _index = i;
            _visitadas.add(i);
          });
        }
      }),
      child: Scaffold(
        body: Row(
          children: [
            // En el ordenador (oficina), menú lateral en vez de barra inferior.
            if (escritorio)
              NavigationRail(
                extended: ancho >= 1200,
                backgroundColor: AppColors.navyDeep,
                selectedIndex: index,
                onDestinationSelected: (v) => setState(() {
                  _index = v;
                  _visitadas.add(v);
                }),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  // Con el menú desplegado, el logo completo con las letras.
                  child: ancho >= 1200
                      ? Image.asset('assets/images/logo_blanco.png', width: 170)
                      : Image.asset('assets/images/emblema_blanco.png',
                          width: 40, height: 40),
                ),
                indicatorColor: AppColors.ball.withValues(alpha: 0.18),
                unselectedIconTheme: const IconThemeData(color: Colors.white70),
                selectedIconTheme: const IconThemeData(color: AppColors.ball),
                unselectedLabelTextStyle:
                    const TextStyle(color: Colors.white70),
                selectedLabelTextStyle: const TextStyle(
                    color: AppColors.ball, fontWeight: FontWeight.w700),
                destinations: [
                  for (final t in tabs)
                    NavigationRailDestination(
                      icon: t.esChat
                          ? _IconoConAviso(icono: t.icon, uid: user.uid)
                          : Icon(t.icon),
                      selectedIcon: t.esChat
                          ? _IconoConAviso(icono: t.selectedIcon, uid: user.uid)
                          : Icon(t.selectedIcon),
                      label: Text(t.label),
                    ),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    if (i == index || _visitadas.contains(i))
                      tabs[i].builder()
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: escritorio
            ? null
            : _BarraInferior(
                child: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (v) => setState(() {
                    _index = v;
                    _visitadas.add(v);
                  }),
                  destinations: [
                    for (final t in tabs)
                      NavigationDestination(
                        icon: t.esChat
                            ? _IconoConAviso(icono: t.icon, uid: user.uid)
                            : Icon(t.icon),
                        selectedIcon: t.esChat
                            ? _IconoConAviso(
                                icono: t.selectedIcon, uid: user.uid)
                            : Icon(t.selectedIcon),
                        label: t.label,
                      ),
                  ],
                ),
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
    return StreamBuilderEstable<int>(
      streamKey: uid,
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
          Image.asset('assets/images/emblema_blanco.png',
              width: 32, height: 32),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: actions,
    );
  }
}

/// Carga del perfil. Si tarda demasiado (mala red) deja de girar sin fin:
/// avisa y ofrece reintentar o salir.
class _CargandoPerfil extends StatefulWidget {
  const _CargandoPerfil();

  @override
  State<_CargandoPerfil> createState() => _CargandoPerfilState();
}

class _CargandoPerfilState extends State<_CargandoPerfil> {
  bool _lento = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _lento = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_lento) return const LoadingView(message: 'Cargando tu perfil…');
    return EmptyState(
      icon: Icons.wifi_off_outlined,
      title: 'Está tardando más de lo normal',
      message: 'Revisa tu conexión. Si estás en una wifi con restricciones, '
          'prueba con datos móviles.',
      action: OutlinedButton.icon(
        onPressed: () => context.read<SessionController>().signOut(),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión y reintentar'),
      ),
    );
  }
}

/// Barra inferior elevada: en el móvil (sobre todo en iPhone con la app en
/// pantalla de inicio) el borde de abajo lo reserva el sistema para sus
/// gestos, y los botones pegados a él no responden bien al toque. Se deja un
/// margen extra para que queden en la zona que sí detecta el dedo.
class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.child});
  final Widget child;

  static const margen = 14.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navyDeep,
      child: Padding(
        padding: const EdgeInsets.only(bottom: margen),
        child: child,
      ),
    );
  }
}
