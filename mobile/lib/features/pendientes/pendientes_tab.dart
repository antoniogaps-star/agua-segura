import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../services/services_repository.dart';

/// **¿A QUIÉN LE TOCA?** — la pantalla estrella.
///
/// Es la respuesta directa al problema que originó la app: "se me olvida a quién le toca
/// renovar o hacer el mantenimiento de 6 meses". Se abre primero, ordenada por urgencia,
/// y cada renglón trae el botón de WhatsApp con el mensaje ya escrito.
class PendientesTab extends ConsumerWidget {
  const PendientesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientes = ref.watch(pendientesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendientesProvider),
      child: pendientes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Aviso(
          icono: Icons.error_outline,
          titulo: 'No se pudo cargar',
          detalle: '$e',
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                _Aviso(
                  icono: Icons.check_circle_outline,
                  titulo: 'Nadie pendiente',
                  detalle: 'Todos tus clientes están al día, o ya tienen su visita '
                      'agendada. Al terminar un servicio, la próxima fecha se anota sola.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _RenglonPendiente(lista[i]),
          );
        },
      ),
    );
  }
}

class _RenglonPendiente extends ConsumerWidget {
  const _RenglonPendiente(this.p);

  final Pendiente p;

  /// Rojo = ya se pasó · Amarillo = esta semana · Verde = este mes.
  /// El color es lo primero que se ve; el texto solo confirma.
  Color _color(BuildContext context) {
    if (p.vencido) return Colors.red.shade600;
    if (p.estaSemana) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  String _mensaje() {
    final servicio = tiposDeServicio[p.tipo] ?? p.tipo;
    final meses = periodicidadMeses[p.tipo] ?? 6;
    return 'Buen día, ${p.cliente.name}. Le escribimos de Agua Segura. '
        'Ya se cumplieron $meses meses de su servicio de '
        '${servicio.toLowerCase()} (última vez: ${fechaLarga(p.ultimoServicio)}). '
        '¿Le agendamos su servicio esta semana?';
  }

  Future<void> _recordar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final abrio = await abrirWhatsApp(p.cliente.phone, _mensaje());
    if (!abrio) {
      messenger.showSnackBar(
        SnackBar(
          content: Text((p.cliente.phone ?? '').isEmpty
              ? 'Ese cliente no tiene teléfono guardado'
              : 'No se pudo abrir WhatsApp'),
        ),
      );
    }
  }

  Future<void> _agendar(BuildContext context, WidgetRef ref) async {
    final cuando = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de la visita',
    );
    if (cuando == null) return;

    await ref.read(servicesRepositoryProvider).agendar(
          clientId: p.cliente.id,
          serviceType: p.tipo,
          scheduledFor: cuando,
        );
    ref.invalidate(pendientesProvider);
    ref.invalidate(agendaHoyProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _color(context);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: Container(
        width: 10,
        height: 48,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      ),
      title: Text(
        p.cliente.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tiposDeServicio[p.tipo] ?? p.tipo),
          Text(
            enPalabras(p.diasVencido),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if ((p.cliente.address ?? '').isNotEmpty)
            Text(
              p.cliente.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
            tooltip: 'Recordarle por WhatsApp',
            onPressed: () => _recordar(context),
          ),
          IconButton(
            icon: const Icon(Icons.event_available),
            tooltip: 'Agendar la visita',
            onPressed: () => _agendar(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.detalle});

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
