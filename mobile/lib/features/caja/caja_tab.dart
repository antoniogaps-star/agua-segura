import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../services/services_repository.dart';

/// **Caja**, en dos pestañas:
///
/// - **Por cobrar**: lo que debe cada cliente, sumado por persona. Aquí se pone o se
///   corrige la cantidad de cada servicio y se marca cuando ya pagó.
/// - **Cobrado**: la suma del día (o de la semana o el mes), con el detalle.
///
/// Todo el negocio es en efectivo, así que no hay tarjetas ni conciliaciones: es lo que
/// el dueño revisa en la noche para saber cuánto entró y a quién le falta cobrarle.
class CajaTab extends ConsumerStatefulWidget {
  const CajaTab({super.key});

  @override
  ConsumerState<CajaTab> createState() => _CajaTabState();
}

/// Lo que necesita pintar la pantalla, cargado de un jalón.
class _Resumen {
  const _Resumen(this.corte, this.porCobrar, this.cobrados, this.clientes);

  final ({int cobrado, int porCobrar, int visitas}) corte;
  final List<({Client cliente, int total, List<ServiceJob> servicios})> porCobrar;
  final List<ServiceJob> cobrados;
  final Map<String, Client> clientes;
}

class _CajaTabState extends ConsumerState<CajaTab> {
  /// 0 = hoy · 1 = esta semana · 2 = este mes
  int _rango = 0;

  (DateTime, DateTime) get _fechas {
    final hoy = DateTime.now();
    return switch (_rango) {
      0 => (hoy, hoy),
      1 => (hoy.subtract(Duration(days: hoy.weekday - 1)), hoy),
      _ => (DateTime(hoy.year, hoy.month, 1), hoy),
    };
  }

  Future<_Resumen> _cargar(ServicesRepository repo, DateTime desde, DateTime hasta) async {
    final clientes = await ref.read(clientsRepositoryProvider).list();
    return _Resumen(
      await repo.corte(desde, hasta),
      await repo.porCobrarPorCliente(),
      await repo.cobradosEntre(desde, hasta),
      {for (final c in clientes) c.id: c},
    );
  }

  @override
  Widget build(BuildContext context) {
    final (desde, hasta) = _fechas;
    final repo = ref.watch(servicesRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Por cobrar'),
              Tab(text: 'Cobrado'),
            ],
          ),
          Expanded(
            child: FutureBuilder<_Resumen>(
              future: _cargar(repo, desde, hasta),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final datos = snap.data!;
                return TabBarView(
                  children: [
                    _PorCobrar(
                      datos: datos,
                      onCambio: () => setState(() {}),
                    ),
                    _Cobrado(
                      datos: datos,
                      rango: _rango,
                      onRango: (r) => setState(() => _rango = r),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que debe cada cliente. Es la pestaña que se abre primero porque es la que trae
/// dinero: son cobros que ya se ganaron y todavía no están en la bolsa.
class _PorCobrar extends ConsumerWidget {
  const _PorCobrar({required this.datos, required this.onCambio});

  final _Resumen datos;
  final VoidCallback onCambio;

  Future<void> _ponerCantidad(
    BuildContext context,
    WidgetRef ref,
    ServiceJob job,
  ) async {
    final control = TextEditingController(
      text: job.priceCents == 0 ? '' : (job.priceCents / 100).toStringAsFixed(2),
    );
    final monto = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cuánto se le cobra?'),
        content: TextField(
          controller: control,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            border: const OutlineInputBorder(),
            helperText: 'Sugerido: ${pesos(precioSugeridoCents[job.serviceType] ?? 0)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final limpio = control.text.replaceAll(RegExp(r'[^0-9.]'), '');
              Navigator.of(ctx).pop(((double.tryParse(limpio) ?? 0) * 100).round());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (monto == null) return;
    await ref.read(servicesRepositoryProvider).ajustarCobro(job, priceCents: monto);
    onCambio();
  }

  Future<void> _marcarPagado(WidgetRef ref, ServiceJob job) async {
    await ref.read(servicesRepositoryProvider).ajustarCobro(job, isPaid: true);
    ref.invalidate(corteDeHoyProvider);
    onCambio();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = datos.porCobrar;
    final total = lista.fold<int>(0, (s, c) => s + c.total);

    if (lista.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 90),
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Nadie te debe nada',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Aquí van a salir los servicios realizados que todavía no te pagan.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Colors.orange.shade50,
          child: ListTile(
            leading: Icon(Icons.schedule, size: 34, color: Colors.orange.shade800),
            title: const Text('Total por cobrar'),
            subtitle: Text('${lista.length} cliente(s)'),
            trailing: Text(
              pesos(total),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final fila in lista)
          Card(
            child: ExpansionTile(
              title: Text(
                fila.cliente.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                fila.servicios.length == 1
                    ? '1 servicio pendiente de pago'
                    : '${fila.servicios.length} servicios pendientes de pago',
              ),
              trailing: Text(
                pesos(fila.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange.shade900,
                ),
              ),
              children: [
                for (final j in fila.servicios)
                  ListTile(
                    dense: true,
                    title: Text(tiposDeServicio[j.serviceType] ?? j.serviceType),
                    subtitle: Text(
                      j.performedOn == null
                          ? ''
                          : fechaLarga(DateTime.parse(j.performedOn!)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _ponerCantidad(context, ref, j),
                          child: Text(
                            j.priceCents == 0 ? 'Poner monto' : pesos(j.priceCents),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green.shade700,
                          tooltip: 'Ya me pagó',
                          onPressed: () => _marcarPagado(ref, j),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// El corte: cuánto entró hoy (o esta semana, o este mes) y de quién.
class _Cobrado extends StatelessWidget {
  const _Cobrado({
    required this.datos,
    required this.rango,
    required this.onRango,
  });

  final _Resumen datos;
  final int rango;
  final ValueChanged<int> onRango;

  @override
  Widget build(BuildContext context) {
    final total = datos.cobrados.fold<int>(0, (s, j) => s + j.priceCents);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Hoy')),
            ButtonSegment(value: 1, label: Text('Semana')),
            ButtonSegment(value: 2, label: Text('Mes')),
          ],
          selected: {rango},
          onSelectionChanged: (s) => onRango(s.first),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  switch (rango) {
                    0 => 'Cobrado hoy',
                    1 => 'Cobrado esta semana',
                    _ => 'Cobrado este mes',
                  },
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  pesos(total),
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  datos.cobrados.length == 1
                      ? '1 servicio cobrado'
                      : '${datos.cobrados.length} servicios cobrados',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (datos.cobrados.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todavía no hay cobros en este periodo.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final j in datos.cobrados)
          Card(
            child: ListTile(
              leading: Icon(Icons.payments_outlined, color: Colors.green.shade700),
              title: Text(datos.clientes[j.clientId]?.name ?? 'Cliente'),
              subtitle: Text(
                '${tiposDeServicio[j.serviceType] ?? j.serviceType} · '
                '${j.performedOn == null ? '' : fechaCorta(DateTime.parse(j.performedOn!))}',
              ),
              trailing: Text(
                pesos(j.priceCents),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
