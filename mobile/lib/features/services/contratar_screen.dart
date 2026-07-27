import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'services_repository.dart';

/// **Contratar un servicio**: lo que se acuerda con el cliente, en una sola pantalla.
///
/// Existe aparte de "agendar" porque son dos momentos distintos del negocio. Agendar es
/// darle fecha a un mantenimiento que ya tocaba; contratar es cerrar un trato nuevo —y
/// ahí sí se acuerda el precio—. Un cliente que apenas entra no aparece en "¿A quién le
/// toca?", porque esa pantalla vive del historial: su primer trabajo se contrata aquí.
class ContratarScreen extends ConsumerStatefulWidget {
  const ContratarScreen({super.key, required this.cliente});

  final Client cliente;

  @override
  ConsumerState<ContratarScreen> createState() => _ContratarScreenState();
}

class _ContratarScreenState extends ConsumerState<ContratarScreen> {
  String _tipo = 'tinacos';
  DateTime _dia = DateTime.now();
  TimeOfDay _hora = const TimeOfDay(hour: 9, minute: 0);
  late final _monto = TextEditingController(
    text: ((precioSugeridoCents['tinacos'] ?? 0) / 100).toStringAsFixed(2),
  );
  final _notas = TextEditingController();
  String? _tecnicoId;
  bool _guardando = false;

  @override
  void dispose() {
    _monto.dispose();
    _notas.dispose();
    super.dispose();
  }

  int get _centavos {
    final limpio = _monto.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return ((double.tryParse(limpio) ?? 0) * 100).round();
  }

  Future<void> _elegirDia() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '¿Qué día se va a hacer?',
    );
    if (elegido != null) setState(() => _dia = elegido);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: '¿A qué hora quedaron?',
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final cuando = DateTime(_dia.year, _dia.month, _dia.day, _hora.hour, _hora.minute);

    final resultado = await ref.read(servicesRepositoryProvider).agendar(
          clientId: widget.cliente.id,
          serviceType: _tipo,
          scheduledFor: cuando,
          priceCents: _centavos,
          technicianId: _tecnicoId,
          notes: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
        );

    ref.invalidate(agendaHoyProvider);
    ref.invalidate(pendientesProvider);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          resultado.reprogramada
              ? 'Ya tenía ese servicio agendado. Se cambió al '
                  '${fechaCorta(cuando)} a las ${hora(cuando)}'
              : 'Contratado: ${fechaCorta(cuando)} a las ${hora(cuando)} · '
                  '${pesos(_centavos)}',
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cuando = DateTime(_dia.year, _dia.month, _dia.day, _hora.hour, _hora.minute);

    return Scaffold(
      appBar: AppBar(title: const Text('Contratar servicio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.cliente.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if ((widget.cliente.address ?? '').isNotEmpty)
            Text(widget.cliente.address!, style: Theme.of(context).textTheme.bodyMedium),
          if ((widget.cliente.directions ?? '').isNotEmpty)
            Text(
              widget.cliente.directions!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 24),

          Text('¿Qué servicio?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _tipo,
            onChanged: (v) => setState(() {
              _tipo = v!;
              // El precio sugerido cambia con el servicio: el del tinaco es fijo y el
              // resto se cotiza, así que ahí se deja en blanco para que lo teclee.
              final sugerido = precioSugeridoCents[v] ?? 0;
              _monto.text = sugerido == 0 ? '' : (sugerido / 100).toStringAsFixed(2);
            }),
            child: Column(
              children: [
                for (final e in tiposDeServicio.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: e.key,
                    title: Text(e.value),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Día'),
            subtitle: Text(fechaLarga(cuando)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _elegirDia,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Hora acordada'),
            subtitle: Text('${hora(cuando)} hrs'),
            trailing: const Icon(Icons.more_time),
            onTap: _elegirHora,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto acordado',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
              helperText: 'Se puede corregir al terminar el trabajo',
            ),
          ),
          const SizedBox(height: 12),
          // A quién le toca hacerlo. Si no se elige, la visita queda sin asignar y el
          // dueño la reparte después desde la agenda.
          _SelectorTecnico(
            actual: _tecnicoId,
            onCambio: (id) => setState(() => _tecnicoId = id),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              hintText: 'Tinaco de 1100 L, azotea de dos aguas…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Contratar'),
          ),
        ],
      ),
    );
  }
}

/// "¿Quién lo va a hacer?" — se elige de entre los técnicos dados de alta.
///
/// Si el negocio todavía no tiene técnicos, no se muestra nada: sería una pregunta sin
/// respuestas posibles.
class _SelectorTecnico extends ConsumerWidget {
  const _SelectorTecnico({required this.actual, required this.onCambio});

  final String? actual;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tecnicos = ref.watch(tecnicosProvider).valueOrNull ?? const <TeamMember>[];
    if (tecnicos.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String?>(
      initialValue: actual,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '¿Quién lo va a hacer?',
        helperText: 'Lo verá en su agenda del día',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Sin asignar')),
        for (final t in tecnicos)
          DropdownMenuItem<String?>(value: t.id, child: Text(t.name ?? t.email)),
      ],
      onChanged: onCambio,
    );
  }
}
