import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';

/// **Mis técnicos**: el dueño los da de alta y cada uno entra con su propia cuenta.
///
/// Que tengan cuenta propia no es un lujo administrativo: es lo que hace que el técnico
/// vea SOLO sus visitas del día y **no** la caja del negocio.
class EquipoScreen extends ConsumerStatefulWidget {
  const EquipoScreen({super.key});

  @override
  ConsumerState<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends ConsumerState<EquipoScreen> {
  bool _sinConexion = false;

  @override
  void initState() {
    super.initState();
    // Se pide al servidor al abrir: si el dueño acaba de dar de alta a alguien desde
    // otro teléfono, tiene que aparecer aquí sin esperar la siguiente sincronización.
    _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      await ref.read(equipoRepositoryProvider).refrescar();
      if (mounted) setState(() => _sinConexion = false);
    } catch (_) {
      // Sin internet se muestra lo último que se sabe, que es mejor que nada.
      if (mounted) setState(() => _sinConexion = true);
    }
    ref.invalidate(equipoProvider);
    ref.invalidate(tecnicosProvider);
  }

  Future<void> _agregar() async {
    final datos = await showModalBottomSheet<({String nombre, String correo, String clave})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const _AltaTecnico(),
      ),
    );
    if (datos == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(equipoRepositoryProvider).agregarTecnico(
            nombre: datos.nombre,
            correo: datos.correo,
            contrasena: datos.clave,
          );
      await _refrescar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${datos.nombre} ya puede entrar con ${datos.correo}',
          ),
        ),
      );
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensajeDeError(e))));
    }
  }

  String _mensajeDeError(DioException e) {
    final codigo = e.response?.data is Map
        ? ((e.response!.data['error'] as Map?)?['code'] as String?)
        : null;
    return switch (codigo) {
      'EMAIL_TAKEN' => 'Ese correo ya lo usa alguien de tu equipo',
      'FORBIDDEN' => 'Solo el dueño puede dar de alta técnicos',
      _ => 'No se pudo dar de alta. Revisa tu internet e inténtalo otra vez.',
    };
  }

  Future<void> _darDeBaja(TeamMember quien) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Dar de baja a ${quien.name ?? quien.email}?'),
        content: const Text(
          'Ya no va a poder entrar a la app. Los trabajos que hizo se quedan '
          'registrados con su nombre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, dar de baja'),
          ),
        ],
      ),
    );
    if (!(seguro ?? false) || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(equipoRepositoryProvider).darDeBaja(quien);
      await _refrescar();
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipo = ref.watch(equipoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi equipo')),
      body: Column(
        children: [
          if (_sinConexion)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(10),
              child: const Text(
                'Sin internet: estás viendo la última lista guardada. '
                'Para dar de alta a alguien necesitas conexión.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: equipo.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
              data: (lista) => ListView(
                children: [
                  for (final m in lista)
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          m.role == 'operator' ? Icons.engineering : Icons.person,
                        ),
                      ),
                      title: Text(m.name ?? m.email),
                      subtitle: Text(
                        '${m.role == 'operator' ? 'Técnico' : 'Dueño'} · ${m.email}',
                      ),
                      trailing: m.role == 'operator'
                          ? IconButton(
                              icon: const Icon(Icons.person_remove_outlined),
                              tooltip: 'Dar de baja',
                              onPressed: () => _darDeBaja(m),
                            )
                          : null,
                    ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Cada técnico entra con su propio correo y contraseña. Ve las '
                      'visitas que le tocan y registra su trabajo, pero no ve la caja '
                      'del negocio.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Técnico'),
      ),
    );
  }
}

class _AltaTecnico extends StatefulWidget {
  const _AltaTecnico();

  @override
  State<_AltaTecnico> createState() => _AltaTecnicoState();
}

class _AltaTecnicoState extends State<_AltaTecnico> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _verClave = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Falta el nombre');
      return;
    }
    if (!_correo.text.contains('@')) {
      setState(() => _error = 'El correo no se ve bien');
      return;
    }
    if (_clave.text.length < 8) {
      setState(() => _error = 'La contraseña necesita al menos 8 letras o números');
      return;
    }
    Navigator.of(context).pop((
      nombre: _nombre.text.trim(),
      correo: _correo.text.trim(),
      clave: _clave.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nuevo técnico', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Luis',
              helperText: 'Es el que aparece en la agenda',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo',
              helperText: 'Con este entra a la app',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clave,
            obscureText: !_verClave,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: 'Mínimo 8. Dásela a él y que la cambie si quiere',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _verClave = !_verClave),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _guardar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Dar de alta'),
          ),
        ],
      ),
    );
  }
}
