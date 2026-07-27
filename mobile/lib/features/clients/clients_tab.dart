import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../services/agendar_visita.dart';
import '../services/contratar_screen.dart';
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
              // +1 por la tarjeta de "quién te trae clientes", que va hasta arriba.
              itemCount: lista.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) =>
                  i == 0 ? const _QuienTraeClientes() : _RenglonCliente(lista[i - 1]),
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

  /// Elegir el servicio y luego agendarlo (el ayudante pregunta día y hora).
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
    await agendarVisita(context, ref, clientId: cliente.id, serviceType: tipo);
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
              tooltip: 'Avisarle la hora de la visita',
              onPressed: () => _avisarVisita(context, cliente),
            ),
          IconButton(
            icon: const Icon(Icons.event_available),
            tooltip: 'Agendar visita',
            onPressed: () => _agendar(context, ref),
          ),
          // Contratar: cerrar un trabajo nuevo con su precio. Es por donde entra el
          // primer servicio de un cliente, que nunca aparece en "¿A quién le toca?".
          IconButton(
            icon: const Icon(Icons.handshake_outlined),
            tooltip: 'Contratar un servicio',
            onPressed: () async {
              final listo = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => ContratarScreen(cliente: cliente)),
              );
              if (listo ?? false) ref.invalidate(clientsProvider);
            },
          ),
        ],
      ),
    );
  }
}

/// Avisarle al cliente a qué hora llega el técnico hoy.
///
/// Pregunta la hora ANTES de abrir WhatsApp porque esa hora ya se acordó con él; la app
/// solo la escribe bonito. Si mandara una hora inventada, el cliente no estaría esperando
/// y se perdería el viaje.
Future<void> _avisarVisita(BuildContext context, Client cliente) async {
  final hora = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
    helpText: '¿A qué hora quedaron?',
    confirmText: 'Avisarle',
  );
  if (hora == null || !context.mounted) return;

  final texto = '${hora.hour.toString().padLeft(2, '0')}:'
      '${hora.minute.toString().padLeft(2, '0')} hrs';
  final messenger = ScaffoldMessenger.of(context);
  if (!await abrirWhatsApp(cliente.phone, mensajeVisitaDeHoy(cliente.name, texto))) {
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
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
  late String? _recomendadoPor = widget.cliente?.referredById;
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
        referredById: _recomendadoPor,
      );
    } else {
      await repo.update(
        widget.cliente!,
        name: _nombre.text.trim(),
        phone: oNulo(_telefono),
        address: oNulo(_direccion),
        directions: oNulo(_referencias),
        notes: oNulo(_notas),
        referredById: _recomendadoPor,
      );
    }
    ref.invalidate(recomendadoresProvider);
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
          const SizedBox(height: 12),
          // Saber de dónde vino cada cliente es lo que permite pedirle otra
          // recomendación a quien ya trajo trabajo.
          _SelectorRecomendador(
            actual: _recomendadoPor,
            excluir: widget.cliente?.id,
            onCambio: (id) => setState(() => _recomendadoPor = id),
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

/// "¿Quién lo recomendó?" — se elige de entre los clientes que ya existen.
class _SelectorRecomendador extends ConsumerWidget {
  const _SelectorRecomendador({
    required this.actual,
    required this.excluir,
    required this.onCambio,
  });

  final String? actual;

  /// El propio cliente que se está editando: nadie se recomienda a sí mismo.
  final String? excluir;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientes = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final opciones = clientes.where((c) => c.id != excluir).toList();
    if (opciones.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String?>(
      initialValue: actual,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '¿Quién lo recomendó?',
        helperText: 'Así sabes a quién agradecerle',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Nadie / llegó solo')),
        for (final c in opciones)
          DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
      ],
      onChanged: onCambio,
    );
  }
}

/// **Quién te trae clientes.** Va arriba de la lista, con los tres que más han
/// recomendado: son a los que conviene volver a pedirles.
class _QuienTraeClientes extends ConsumerWidget {
  const _QuienTraeClientes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(recomendadoresProvider).valueOrNull ?? const [];
    if (lista.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volunteer_activism_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Quién te trae clientes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in lista.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(r.cliente.name)),
                    Text(
                      r.recomendados == 1
                          ? '1 recomendado'
                          : '${r.recomendados} recomendados',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                      tooltip: 'Agradecerle y pedirle otra',
                      onPressed: () => abrirWhatsApp(
                        r.cliente.phone,
                        mensajeRecomiendanos(r.cliente.name),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
