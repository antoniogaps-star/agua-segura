import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';

/// Agendar una visita: pregunta **día y hora**, guarda y avisa qué pasó.
///
/// Vive aquí y no dentro de una pantalla porque se agenda desde dos lados —"¿a quién le
/// toca?" y la ficha del cliente— y las dos tienen que comportarse igual.
///
/// La HORA se pregunta siempre. Sin ella la visita quedaba a las 00:00 y el aviso por
/// WhatsApp le decía al cliente "hoy estaremos con ustedes a las 00:00 hrs", que es
/// justo lo contrario de lo que se busca: dar certeza.
Future<void> agendarVisita(
  BuildContext context,
  WidgetRef ref, {
  required String clientId,
  required String serviceType,
}) async {
  final dia = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    helpText: '¿Qué día se va a hacer?',
  );
  if (dia == null || !context.mounted) return;

  final horaElegida = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
    helpText: '¿A qué hora quedaron?',
  );
  if (horaElegida == null || !context.mounted) return;

  final cuando = DateTime(dia.year, dia.month, dia.day, horaElegida.hour, horaElegida.minute);
  final messenger = ScaffoldMessenger.of(context);

  final resultado = await ref.read(servicesRepositoryProvider).agendar(
        clientId: clientId,
        serviceType: serviceType,
        scheduledFor: cuando,
      );

  ref.invalidate(agendaHoyProvider);
  ref.invalidate(pendientesProvider);

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        resultado.reprogramada
            // Aviso explícito: si el usuario creía estar agendando una segunda visita,
            // tiene que enterarse de que se movió la que ya había.
            ? 'Ya tenía una visita agendada. Se cambió al '
                '${fechaCorta(cuando)} a las ${hora(cuando)}'
            : 'Visita agendada el ${fechaCorta(cuando)} a las ${hora(cuando)}',
      ),
    ),
  );
}
