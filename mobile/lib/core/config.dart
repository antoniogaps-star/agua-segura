/// Configuración de la app móvil.
class AppConfig {
  /// Base de la API. En el emulador de Android, 10.0.2.2 apunta al host.
  /// Se puede sobreescribir en tiempo de compilación:
  ///   flutter run --dart-define=API_URL=https://api.miservidor.com/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}
