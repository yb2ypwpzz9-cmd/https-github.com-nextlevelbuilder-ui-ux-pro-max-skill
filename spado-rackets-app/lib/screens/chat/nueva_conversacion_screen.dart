import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/alumna.dart';
import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../widgets/common.dart';

/// Elegir a quién escribir. Una familia sólo ve a Dirección y al staff.
/// Dirección ve además, junto a cada familia, el alumnado vinculado y su
/// correo, y puede buscar por cualquiera de los tres: así no se escribe a una
/// cuenta de pruebas antigua sin darse cuenta.
class NuevaConversacionScreen extends StatefulWidget {
  const NuevaConversacionScreen({super.key});

  @override
  State<NuevaConversacionScreen> createState() =>
      _NuevaConversacionScreenState();
}

class _NuevaConversacionScreenState extends State<NuevaConversacionScreen> {
  String _busqueda = '';

  late final ClubRepository _repo = context.read<ClubRepository>();
  late final AppUser _yo = context.read<SessionController>().appUser!;
  late final Stream<List<EntradaDirectorio>> _directorio =
      _repo.watchDirectorio(_yo);
  late final Stream<List<Alumna>> _alumnas = _yo.role.isDireccion
      ? _repo.watchTodasLasAlumnas()
      : Stream.value(const <Alumna>[]);
  late final Stream<List<AppUser>> _familias = _yo.role.isDireccion
      ? _repo.watchFamilias()
      : Stream.value(const <AppUser>[]);

  @override
  Widget build(BuildContext context) {
    final yo = _yo;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo mensaje')),
      body: StreamView<List<EntradaDirectorio>>(
        stream: _directorio,
        builder: (context, personas) => StreamView<List<Alumna>>(
          stream: _alumnas,
          builder: (context, alumnas) => StreamView<List<AppUser>>(
            stream: _familias,
            builder: (context, familias) =>
                _contenido(context, yo, personas, alumnas, familias),
          ),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AppUser yo,
    List<EntradaDirectorio> personas,
    List<Alumna> alumnas,
    List<AppUser> familias,
  ) {
    final hijos = <String, List<String>>{};
    for (final a in alumnas.where((a) => a.activa)) {
      final uid = a.familiaUid;
      if (uid != null) (hijos[uid] ??= []).add(a.nombre);
    }
    final correo = {for (final f in familias) f.uid: f.email};
    bool coincide(EntradaDirectorio p, String q) =>
        p.nombre.toLowerCase().contains(q) ||
        (hijos[p.uid] ?? const []).any((n) => n.toLowerCase().contains(q)) ||
        (correo[p.uid] ?? '').toLowerCase().contains(q);

    final q = _busqueda.trim().toLowerCase();
    final lista = personas.where((p) => q.isEmpty || coincide(p, q)).toList()
      // Primero el entrenador de su grupo, luego Dirección, luego el resto.
      ..sort((a, b) {
        int peso(EntradaDirectorio e) => e.rol.isStaff && _esDeMiGrupo(yo, e)
            ? 0
            : switch (e.rol) {
                UserRole.direccion => 1,
                UserRole.staff => 2,
                UserRole.familia => 3,
              };
        final c = peso(a).compareTo(peso(b));
        return c != 0 ? c : a.nombre.compareTo(b.nombre);
      });
    return PageBody(
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: yo.role.isDireccion
                ? 'Buscar por familia, alumno/a o correo'
                : 'Buscar por nombre',
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          const EmptyState(
            compacto: true,
            icon: Icons.person_search_outlined,
            title: 'Nadie coincide con la búsqueda',
          )
        else
          CardList(
            children: [
              for (final p in lista)
                ListTile(
                  leading: Avatar(inicialesDe(p.nombre)),
                  title: Text(p.nombre),
                  isThreeLine: yo.role.isDireccion &&
                      p.rol == UserRole.familia &&
                      (correo[p.uid] ?? '').isNotEmpty,
                  subtitle: Text(
                    p.rol.isStaff && _esDeMiGrupo(yo, p)
                        ? 'Tu entrenador/a'
                        : p.rol.isStaff
                            ? 'Entrenador'
                            : yo.role.isDireccion && p.rol == UserRole.familia
                                ? [
                                    (hijos[p.uid] ?? const []).isEmpty
                                        ? 'Familia · sin alumnado vinculado'
                                        : 'Familia de ${hijos[p.uid]!.join(', ')}',
                                    if ((correo[p.uid] ?? '').isNotEmpty)
                                      correo[p.uid]!,
                                  ].join('\n')
                                : p.rol.label,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushReplacement(
                    '/chat/${Conversacion.idDirecta(yo.uid, p.uid)}',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

bool _esDeMiGrupo(AppUser yo, EntradaDirectorio e) =>
    yo.role.isFamilia && e.grupos.any(yo.grupos.contains);
