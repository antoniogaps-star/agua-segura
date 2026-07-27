import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../services/services_repository.dart';

/// Los clientes del negocio. Llegan por recomendación, uno por uno, así que cada ficha
/// vale mucho: se guarda el WhatsApp (por donde sale todo) y las referencias para llegar.
class ClientsTab extends ConsumerWidget {
  const ClientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientes = ref.watch(clientsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(clientsProvider),
        child: clientes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
          data: (lista) {
            if (lista.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.people_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Todavía no hay clientes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(child: Text('Toca el botón + para agregar el primero')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _RenglonCliente(lista[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditor(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Cliente'),
      ),
    );
  }
}

class _RenglonCliente extends ConsumerWidget {
  const _RenglonCliente(this.cliente);

  final Client cliente;

  Future<void> _agendar(BuildContext context, WidgetRef ref) async {
    final tipo = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('¿Qué servicio?')),
            for (final e in tiposDeServicio.entries)
              ListTile(
                title: Text(e.value),
                onTap: () => Navigator.of(context).pop(e.key),
              ),
          ],
        ),
      ),
    );
    if (tipo == null || !context.mounted) return;

    final cuando = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de la visita',
    );
    if (cuando == null) return;

    await ref.read(servicesRepositoryProvider).agendar(
          clientId: cliente.id,
          serviceType: tipo,
          scheduledFor: cuando,
        );
    ref.invalidate(agendaHoyProvider);
    ref.invalidate(pendientesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(cliente.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((cliente.address ?? '').isNotEmpty) Text(cliente.address!),
          if ((cliente.directions ?? '').isNotEmpty)
            Text(
              cliente.directions!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
      onTap: () => _abrirEditor(context, ref, cliente),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((cliente.phone ?? '').isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
              tooltip: 'WhatsApp',
              onPressed: () => abrirWhatsApp(cliente.phone, 'Hola ${cliente.name}, '
                  'le escribimos de Agua Segura.'),
            ),
          IconButton(
            icon: const Icon(Icons.event_available),
            tooltip: 'Agendar visita',
            onPressed: () => _agendar(context, ref),
          ),
        ],
      ),
    );
  }
}

Future<void> _abrirEditor(BuildContext context, WidgetRef ref, Client? cliente) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _EditorCliente(cliente: cliente),
    ),
  );
  if (guardado ?? false) ref.invalidate(clientsProvider);
}

class _EditorCliente extends ConsumerStatefulWidget {
  const _EditorCliente({required this.cliente});

  final Client? cliente;

  @override
  ConsumerState<_EditorCliente> createState() => _EditorClienteState();
}

class _EditorClienteState extends ConsumerState<_EditorCliente> {
  late final _nombre = TextEditingController(text: widget.cliente?.name ?? '');
  late final _telefono = TextEditingController(text: widget.cliente?.phone ?? '');
  late final _direccion = TextEditingController(text: widget.cliente?.address ?? '');
  late final _referencias = TextEditingController(text: widget.cliente?.directions ?? '');
  late final _notas = TextEditingController(text: widget.cliente?.notes ?? '');
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _referencias.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Falta el nombre')));
      return;
    }
    setState(() => _guardando = true);
    final repo = ref.read(clientsRepositoryProvider);
    String? oNulo(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    if (widget.cliente == null) {
      await repo.add(
        name: _nombre.text.trim(),
        phone: oNulo(_telefono),
        address: oNulo(_direccion),
        directions: oNulo(_referencias),
        notes: oNulo(_notas),
      );
    } else {
      await repo.update(
        widget.cliente!,
        name: _nombre.text.trim(),
        phone: oNulo(_telefono),
        address: oNulo(_direccion),
        directions: oNulo(_referencias),
        notes: oNulo(_notas),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp',
              helperText: 'Por aquí sale el recordatorio y el certificado',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _direccion,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referencias,
            decoration: const InputDecoration(
              labelText: 'Cómo llegar',
              hintText: 'Portón verde, junto a la tienda',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
