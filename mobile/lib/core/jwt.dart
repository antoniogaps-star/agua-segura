import 'dart:convert';

/// Decodifica el payload de un JWT (sin verificar la firma — solo para leer claims
/// locales como tenant_id). La verificación real la hace el backend.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return json.decode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
