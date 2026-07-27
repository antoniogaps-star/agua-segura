import 'package:dio/dio.dart';

import '../../core/jwt.dart';
import '../../core/secure_store.dart';

/// Acceso a los endpoints de autenticación y perfil.
class AuthRepository {
  AuthRepository(this._dio, this._store);

  final Dio _dio;
  final SecureStore _store;

  Future<void> login({
    required String companySlug,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'company_slug': companySlug,
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data);
  }

  Future<void> register({
    required String companyName,
    required String companySlug,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'company_name': companyName,
      'company_slug': companySlug,
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data);
  }

  /// Indica si el servidor ya tiene configurado un secreto de administrador
  /// (por variable de entorno o configurado desde la app). No revela su valor.
  Future<bool> adminConfigured() async {
    final response = await _dio.get('/auth/admin-status');
    return (response.data as Map)['admin_secret_configured'] == true;
  }

  /// Configura POR PRIMERA VEZ el secreto de administrador desde la app. Solo
  /// funciona si aún no hay ninguno (si ya existe, el servidor responde 409).
  Future<void> bootstrapAdmin(String secret) async {
    await _dio.post('/auth/admin/bootstrap', data: {'secret': secret});
  }

  /// Restablece la contraseña de una cuenta. Requiere el secreto de administrador,
  /// que se envía en el CUERPO (JSON admite cualquier carácter: acentos, ñ, emojis…).
  /// Antes iba en un header HTTP, que no admite no-ASCII y hacía fallar la petición.
  /// Pensado para recuperar el acceso de un cliente.
  Future<void> resetPassword({
    required String companySlug,
    required String email,
    required String newPassword,
    required String adminSecret,
  }) async {
    await _dio.post(
      '/auth/reset-password',
      data: {
        'company_slug': companySlug,
        'email': email,
        'new_password': newPassword,
        'admin_secret': adminSecret,
      },
    );
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/users/me');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout() async {
    final refresh = await _store.refreshToken;
    if (refresh != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh});
      } catch (_) {
        // aunque falle la revocación en servidor, cerramos sesión localmente
      }
    }
    await _store.clear();
  }

  Future<bool> hasSession() async => (await _store.refreshToken) != null;

  /// Tenant del usuario, leído del JWT guardado. Se usa para etiquetar los
  /// registros locales; el servidor lo reimpone al sincronizar.
  Future<String> currentTenantId() async {
    final token = await _store.accessToken ?? await _store.refreshToken;
    if (token == null) return '';
    return decodeJwtPayload(token)?['tenant_id'] as String? ?? '';
  }

  Future<void> _saveTokens(dynamic data) async {
    await _store.saveTokens(
      data['access_token'] as String,
      data['refresh_token'] as String,
    );
  }
}
