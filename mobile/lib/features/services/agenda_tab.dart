import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'completar_screen.dart';
import 'services_repository.dart';

/// **La agenda del técnico**: qué visitas hay hoy.
///
/// Está pensada para verse en la calle, con una mano: pocos datos, letra grande y —lo
/// más importante— las *referencias para llegar*, que es lo que de verdad usa para
/// encontrar la casa.
class AgendaTab extends ConsumerWidget {
  const AgendaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaHoyProvider);
    final clientes = ref.watch(clientsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(agendaHoyProvider);
        ref.invalidate(clientsProvider);
      },
      child: agenda.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
        data: (visitas) {
          if (visitas.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.wb_sunny_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'No hay visitas para hoy',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('Las visitas se agendan desde "¿A quién le toca?"'),
                ),
              ],
            );
          }

          final porId = {
            for (final c in clientes.valueOrNull ?? const <Client>[]) c.id: c,
          };
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: visitas.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _RenglonVisita(
              visita: visitas[i],
              cliente: porId[visitas[i].clientId],
            ),
          );
        },
      ),
    );
  }
}

class _RenglonVisita extends ConsumerWidget {
  const _RenglonVisita({required this.visita, required this.cliente});

  final ServiceJob visita;
  final Client? cliente;

  Future<void> _terminar(BuildContext context, WidgetRef ref) async {
    final listo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompletarScreen(visita: visita, cliente: cliente),
      ),
    );
    if (listo ?? false) {
      ref.invalidate(agendaHoyProvider);
      ref.invalidate(pendientesProvider);
      ref.invalidate(corteDeHoyProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = cliente?.name ?? 'Cliente';
    final referencias = cliente?.directions ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          visita.scheduledFor == null ? '—' : hora(visita.scheduledFor!),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tiposDeServicio[visita.serviceType] ?? visita.serviceType),
          if ((cliente?.address ?? '').isNotEmpty) Text(cliente!.address!),
          if (referencias.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      referencias,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avisarle que hoy va el técnico, con la hora que ya quedó agendada.
          if ((cliente?.phone ?? '').isNotEmpty && visita.scheduledFor != null)
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
              tooltip: 'Avisarle que hoy vamos',
              onPressed: () => abrirWhatsApp(
                cliente!.phone,
                mensajeVisitaDeHoy(cliente!.name, '${hora(visita.scheduledFor!)} hrs'),
              ),
            ),
          FilledButton(
            onPressed: () => _terminar(context, ref),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
  }
}
