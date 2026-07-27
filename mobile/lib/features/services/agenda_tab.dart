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
                // Un cliente NUEVO nunca sale en "¿A quién le toca?": esa pantalla vive
                // del historial y él todavía no tiene. Su primer trabajo se contrata
                // desde Clientes.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Contrata el servicio desde "Clientes", o agéndalo desde '
                    '"¿A quién le toca?" si ya le tocaba su mantenimiento.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          final porId = {
            for (final c in clientes.valueOrNull ?? const <Client>[]) c.id: c,
          };
          final equipo = {
            for (final t in ref.watch(equipoProvider).valueOrNull ?? const <TeamMember>[])
              t.id: t,
          };
          return ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            itemCount: visitas.length,
            itemBuilder: (_, i) => _RenglonVisita(
              visita: visitas[i],
              cliente: porId[visitas[i].clientId],
              tecnico: equipo[visitas[i].technicianId],
            ),
          );
        },
      ),
    );
  }
}

class _RenglonVisita extends ConsumerWidget {
  const _RenglonVisita({
    required this.visita,
    required this.cliente,
    required this.tecnico,
  });

  final ServiceJob visita;
  final Client? cliente;
  final TeamMember? tecnico;

  /// Cancelar la visita: el cliente no estaba, la pospuso, o quedó duplicada.
  ///
  /// Pide confirmación porque desde aquí no se puede deshacer, y no borra el registro:
  /// lo marca como cancelado. Así el servidor y los demás celulares se enteran — un
  /// borrado a secas se quedaría solo en este teléfono.
  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta visita?'),
        content: Text(
          'Se quita de la agenda de hoy. '
          '${cliente?.name ?? 'El cliente'} volverá a aparecer en "¿A quién le toca?" '
          'si ya le tocaba su mantenimiento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (!(seguro ?? false)) return;

    await ref.read(servicesRepositoryProvider).cancelar(visita);
    ref.invalidate(agendaHoyProvider);
    ref.invalidate(pendientesProvider);
  }

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
    final puedeAvisar =
        (cliente?.phone ?? '').isNotEmpty && visita.scheduledFor != null;

    // Tarjeta y no renglón: los datos van arriba a todo lo ancho y los botones abajo.
    // Apretados en una sola línea, "Impermeabilización" se partía a media palabra y el
    // técnico lee esto en la calle, con una mano y a contraluz.
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    visita.scheduledFor == null ? '—' : hora(visita.scheduledFor!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tiposDeServicio[visita.serviceType] ?? visita.serviceType,
                            ),
                          ),
                          // El monto acordado, a la vista: el técnico llega sabiendo
                          // cuánto va a cobrar, sin hablarle al dueño a preguntar.
                          if (visita.priceCents > 0)
                            Text(
                              pesos(visita.priceCents),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      if ((cliente?.address ?? '').isNotEmpty)
                        Text(
                          cliente!.address!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      // Quién la va a hacer: sin esto, dos técnicos podrían presentarse
                      // en la misma casa, o ninguno.
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.engineering_outlined, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              tecnico?.name ?? tecnico?.email ?? 'Sin asignar',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: tecnico == null
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (referencias.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.pin_drop_outlined, size: 15),
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
                ),
              ],
            ),
            Row(
              children: [
                // Avisarle que hoy va el técnico, con la hora que ya quedó agendada.
                if (puedeAvisar)
                  TextButton.icon(
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                    label: const Text('Avisar'),
                    onPressed: () => abrirWhatsApp(
                      cliente!.phone,
                      mensajeVisitaDeHoy(
                        cliente!.name,
                        '${hora(visita.scheduledFor!)} hrs',
                      ),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => _terminar(context, ref),
                  child: const Text('Terminar'),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Más',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (hoja) => SafeArea(
                      child: ListTile(
                        leading: const Icon(Icons.event_busy),
                        title: const Text('Cancelar esta visita'),
                        onTap: () {
                          Navigator.of(hoja).pop();
                          _cancelar(context, ref);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
