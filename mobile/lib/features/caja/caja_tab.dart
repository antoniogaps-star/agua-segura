import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../services/services_repository.dart';

/// **Corte de caja**: cuánto se cobró y qué falta por cobrar.
///
/// Todo el negocio es en efectivo, así que no hay tarjetas ni conciliaciones: solo dos
/// números y la lista de quién quedó debiendo, que es lo que el dueño revisa en la tarde.
class CajaTab extends ConsumerStatefulWidget {
  const CajaTab({super.key});

  @override
  ConsumerState<CajaTab> createState() => _CajaTabState();
}

/// Lo que necesita pintar la pantalla, cargado de un jalón.
class _Resumen {
  const _Resumen(this.corte, this.trabajos, this.clientes);

  final ({int cobrado, int porCobrar, int visitas}) corte;
  final List<ServiceJob> trabajos;
  final List<Client> clientes;
}

class _CajaTabState extends ConsumerState<CajaTab> {
  Future<_Resumen> _cargar(
    ServicesRepository repo,
    DateTime desde,
    DateTime hasta,
  ) async =>
      _Resumen(
        await repo.corte(desde, hasta),
        await repo.list(),
        await ref.read(clientsRepositoryProvider).list(),
      );

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

  @override
  Widget build(BuildContext context) {
    final (desde, hasta) = _fechas;
    final repo = ref.watch(servicesRepositoryProvider);

    return FutureBuilder<_Resumen>(
      future: _cargar(repo, desde, hasta),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final corte = snap.data!.corte;
        final porId = {for (final c in snap.data!.clientes) c.id: c};

        // Quién quedó debiendo, dentro del rango elegido.
        final deudores = snap.data!.trabajos.where((j) {
          if (j.status != 'realizado' || j.isPaid || j.performedOn == null) return false;
          final dia = DateTime.parse(j.performedOn!);
          return !dia.isBefore(DateTime(desde.year, desde.month, desde.day)) &&
              !dia.isAfter(DateTime(hasta.year, hasta.month, hasta.day));
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Hoy')),
                ButtonSegment(value: 1, label: Text('Semana')),
                ButtonSegment(value: 2, label: Text('Mes')),
              ],
              selected: {_rango},
              onSelectionChanged: (s) => setState(() => _rango = s.first),
            ),
            const SizedBox(height: 20),
            _Tarjeta(
              titulo: 'Cobrado',
              monto: corte.cobrado,
              color: Colors.green.shade600,
              icono: Icons.payments_outlined,
              detalle: '${corte.visitas} '
                  '${corte.visitas == 1 ? 'servicio realizado' : 'servicios realizados'}',
            ),
            const SizedBox(height: 12),
            _Tarjeta(
              titulo: 'Por cobrar',
              monto: corte.porCobrar,
              color: Colors.orange.shade700,
              icono: Icons.schedule,
              detalle: deudores.isEmpty ? 'Nadie debe nada' : '${deudores.length} pendiente(s)',
            ),
            if (deudores.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Quién debe', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final j in deudores)
                Card(
                  child: ListTile(
                    title: Text(porId[j.clientId]?.name ?? 'Cliente'),
                    subtitle: Text(
                      '${tiposDeServicio[j.serviceType] ?? j.serviceType} · '
                      '${fechaCorta(DateTime.parse(j.performedOn!))}',
                    ),
                    trailing: Text(
                      pesos(j.priceCents),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _marcarPagado(j),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Toca un renglón cuando ya te hayan pagado.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _marcarPagado(ServiceJob j) async {
    await ref.read(servicesRepositoryProvider).completar(
          j,
          priceCents: j.priceCents,
          isPaid: true,
          performedOn: DateTime.parse(j.performedOn!),
        );
    ref.invalidate(corteDeHoyProvider);
    setState(() {});
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.titulo,
    required this.monto,
    required this.color,
    required this.icono,
    required this.detalle,
  });

  final String titulo;
  final int monto;
  final Color color;
  final IconData icono;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icono, size: 36, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    pesos(monto),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                  Text(detalle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
