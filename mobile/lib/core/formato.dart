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
