import 'package:url_launcher/url_launcher.dart';

/// Dinero en pesos, a partir de centavos. Todo se guarda en centavos para que no se
/// pierda un peso por redondeo.
String pesos(int centavos) => '\$${(centavos / 100).toStringAsFixed(2)}';

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "15 de enero de 2026". Se escribe con letra a propósito: va en mensajes que lee el
/// cliente, y "15/01" se puede confundir con "1 de mayo" según a qué esté acostumbrado.
String fechaLarga(DateTime d) => '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

/// "15 ene" — para listas, donde no cabe la fecha completa.
String fechaCorta(DateTime d) => '${d.day} ${_meses[d.month - 1].substring(0, 3)}';

String hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Cuánto tiempo lleva vencido, en palabras. "van 7 meses" se entiende mejor que
/// "hace 213 días".
String enPalabras(int dias) {
  final abs = dias.abs();
  final texto = switch (abs) {
    0 => 'hoy',
    1 => '1 día',
    < 30 => '$abs días',
    < 60 => '1 mes',
    < 365 => '${(abs / 30).round()} meses',
    < 730 => '1 año',
    _ => '${(abs / 365).round()} años',
  };
  if (abs == 0) return 'Le toca hoy';
  return dias > 0 ? 'Van $texto de retraso' : 'En $texto';
}

/// Abre WhatsApp con el mensaje ya escrito. Devuelve false si no se pudo.
///
/// El dueño solo revisa y le da enviar: escribir el mensaje a mano era justo la fricción
/// que hacía que no lo mandara nunca.
Future<bool> abrirWhatsApp(String? telefono, String mensaje) async {
  final numero = (telefono ?? '').replaceAll(RegExp(r'\D'), '');
  if (numero.isEmpty) return false;
  final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// El aviso de que hoy le toca su visita, a la hora que ya se acordó con él.
///
/// La hora NO la inventa la app: primero se pone de acuerdo con el cliente (por teléfono
/// o por el mismo WhatsApp) y ya con eso se le manda la confirmación. Un aviso con una
/// hora que el cliente no aceptó no sirve de nada: nadie va a estar esperando.
String mensajeVisitaDeHoy(String nombreCliente, String horaAcordada) =>
    'Hola $nombreCliente, le escribimos de Agua Segura para informarle que hoy '
    'estaremos con ustedes a las $horaAcordada. ¡Gracias por su confianza!';

/// El mensaje para pedirle a un cliente que los recomiende.
///
/// Se manda JUSTO después del certificado, cuando acaba de ver su tinaco limpio: es el
/// único momento en que pedir una recomendación no se siente como pedir un favor.
/// El WhatsApp del negocio, el que se le pasa al vecino que recibe la recomendación.
///
/// Va aquí como constante porque hoy la app la usa un solo negocio. Si se le vende a
/// otro del mismo giro, esto tiene que salir de la ficha de la empresa, no del código.
const whatsappDelNegocio = '7225910426';

/// Menciona TODOS los servicios a propósito: el vecino que recibe este mensaje quizá no
/// necesita lavar su tinaco, pero sí impermeabilizar. Si solo se nombra el servicio que
/// se acaba de hacer, se pierden los otros cuatro.
String mensajeRecomiendanos(String nombreCliente) =>
    '$nombreCliente, muchas gracias por su confianza. '
    'Si conoce a algún vecino o familiar que necesite lavar su tinaco, '
    'impermeabilización de azotea, mantenimiento de techos, mantenimiento de '
    'calentadores solares, instalación o reparación de plomería u otros, '
    '¿nos recomienda? Le pasamos nuestro contacto para que lo comparta: '
    'WhatsApp $whatsappDelNegocio\n\n'
    '*Agua Segura* — Protegemos tu hogar desde lo más alto.';
