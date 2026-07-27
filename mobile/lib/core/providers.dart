import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/sync/sync_service.dart';
import '../features/auth/auth_repository.dart';
import '../features/clients/clients_repository.dart';
import '../features/services/services_repository.dart';
import 'api_client.dart';
import 'secure_store.dart';

/// Tipo de sesión activa: ninguna (mostrar login) o real (negocio de verdad).
enum SessionKind { none, real }

/// Inyección de dependencias con Riverpod.
final secureStoreProvider = Provider<SecureStore>((_) => const SecureStore());

final dioProvider = Provider<Dio>(
  (ref) => createDio(ref.watch(secureStoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(secureStoreProvider)),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.encrypted(ref.watch(secureStoreProvider));
  ref.onDispose(db.close);
  return db;
});

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(databaseProvider), ref.watch(dioProvider)),
);

// ── Clientes ─────────────────────────────────────────────────
final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(
    ref.watch(databaseProvider),
    ref.watch(authRepositoryProvider).currentTenantId,
  ),
);

final clientsProvider = FutureProvider.autoDispose<List<Client>>(
  (ref) => ref.watch(clientsRepositoryProvider).list(),
);

// ── Servicios ────────────────────────────────────────────────
final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(
    ref.watch(databaseProvider),
    ref.watch(authRepositoryProvider).currentTenantId,
  ),
);

/// La agenda de hoy: qué visitas hay y a quién le tocan.
final agendaHoyProvider = FutureProvider.autoDispose<List<ServiceJob>>(
  (ref) => ref.watch(servicesRepositoryProvider).agendaDe(DateTime.now()),
);

/// ¿A quién le toca? — la pantalla estrella.
final pendientesProvider = FutureProvider.autoDispose<List<Pendiente>>(
  (ref) => ref.watch(servicesRepositoryProvider).pendientes(),
);

/// Corte de caja del día.
final corteDeHoyProvider =
    FutureProvider.autoDispose<({int cobrado, int porCobrar, int visitas})>((ref) {
  final hoy = DateTime.now();
  return ref.watch(servicesRepositoryProvider).corte(hoy, hoy);
});

/// Cuenta recordada en este equipo (negocio + correo). Si existe, al abrir la app
/// se muestra la pantalla verde de "Entrar" (solo pide contraseña); si no, "Crear cuenta".
final savedAccountProvider = FutureProvider<(String company, String email)?>((ref) async {
  final store = ref.watch(secureStoreProvider);
  final company = await store.lastCompany;
  final email = await store.lastEmail;
  if (company == null || email == null || company.isEmpty || email.isEmpty) return null;
  return (company, email);
});

/// Estado de sesión: real (token guardado) o ninguna.
class AuthController extends AsyncNotifier<SessionKind> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<SessionKind> build() async {
    return (await _repo.hasSession()) ? SessionKind.real : SessionKind.none;
  }

  /// Inicia sesión. NO usa AsyncLoading para no reemplazar la pantalla de login
  /// mientras se procesa; lanza la excepción si falla y la pantalla la muestra.
  Future<void> login({
    required String companySlug,
    required String email,
    required String password,
  }) async {
    await _repo.login(companySlug: companySlug, email: email, password: password);
    state = const AsyncData(SessionKind.real);
  }

  Future<void> register({
    required String companyName,
    required String companySlug,
    required String email,
    required String password,
  }) async {
    await _repo.register(
      companyName: companyName,
      companySlug: companySlug,
      email: email,
      password: password,
    );
    state = const AsyncData(SessionKind.real);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(SessionKind.none);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, SessionKind>(AuthController.new);
