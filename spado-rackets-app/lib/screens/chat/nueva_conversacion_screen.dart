import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../services/auth_service.dart';
import '../../services/club_repository.dart';
import '../../widgets/common.dart';

/// Elegir a quién escribir. Una familia sólo ve a Dirección y al staff.
class NuevaConversacionScreen extends StatefulWidget {
  const NuevaConversacionScreen({super.key});

  @override
  State<NuevaConversacionScreen> createState() =>
      _NuevaConversacionScreenState();
}

class _NuevaConversacionScreenState extends State<NuevaConversacionScreen> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final yo = context.watch<SessionController>().appUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo mensaje')),
      body: StreamView<List<EntradaDirectorio>>(
        stream: context.read<ClubRepository>().watchDirectorio(yo),
        builder: (context, personas) {
          final q = _busqueda.trim().toLowerCase();
          final lista = personas
              .where((p) => q.isEmpty || p.nombre.toLowerCase().contains(q))
              .toList()
            // Primero el entrenador de su grupo, luego Dirección, luego el resto.
            ..sort((a, b) {
              int peso(EntradaDirectorio e) =>
                  e.rol.isStaff && _esDeMiGrupo(yo, e)
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
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre',
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
                        subtitle: Text(
                          p.rol.isStaff && _esDeMiGrupo(yo, p)
                              ? 'Tu entrenador/a'
                              : p.rol.isStaff
                                  ? 'Entrenador'
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
        },
      ),
    );
  }
}

bool _esDeMiGrupo(AppUser yo, EntradaDirectorio e) =>
    yo.role.isFamilia && e.grupos.any(yo.grupos.contains);
