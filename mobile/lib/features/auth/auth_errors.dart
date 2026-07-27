import 'package:dio/dio.dart';

/// Traduce el error de un intento de login/registro a un mensaje claro y accionable,
/// para que el usuario sepa QUÉ pasó en vez de solo ver la pantalla de nuevo.
String authErrorMessage(Object? error, {required bool isRegister}) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 401) {
      return 'Correo o contraseña incorrectos para esa empresa.';
    }
    if (code == 409) {
      return isRegister
          ? 'Ese nombre de empresa ya está registrado. Si es tuya, toca '
              '"¿Ya tienes empresa? Entrar" y usa tu contraseña; si no, usa otro nombre.'
          : 'Ya existe una empresa con ese nombre. Usa otro nombre o agrégale algo.';
    }
    if (code == 422) {
      return 'Revisa el nombre de la empresa y el correo (correo válido, nombre con letras).';
    }
    if (code != null && code >= 500) {
      return 'El servidor tuvo un problema. Espera unos segundos y vuelve a intentar.';
    }
    // Sin respuesta del servidor: casi siempre es que está "despertando" (plan gratis).
    return 'No pude conectar con el servidor. Puede estar despertando: '
        'espera ~1 minuto y vuelve a intentar.';
  }
  return isRegister
      ? 'No se pudo crear la cuenta. Inténtalo de nuevo.'
      : 'No se pudo entrar. Revisa tus datos e inténtalo de nuevo.';
}
