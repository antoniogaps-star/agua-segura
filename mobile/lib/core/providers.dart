import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/sync/sync_service.dart';
import '../features/auth/auth_repository.dart';
import '../features/clients/clients_repository.dart';
import '../features/equipo/equipo_repository.dart';
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

/// Quién te trae clientes: los que han recomendado a alguien.
final recomendadoresProvider =
    FutureProvider.autoDispose<List<({Client cliente, int recomendados})>>(
  (ref) => ref.watch(clientsRepositoryProvider).recomendadores(),
);

// ── Equipo (dueño y técnicos) ────────────────────────────────
final equipoRepositoryProvider = Provider<EquipoRepository>(
  (ref) => EquipoRepository(ref.watch(databaseProvider), ref.watch(dioProvider)),
);

final equipoProvider = FutureProvider.autoDispose<List<TeamMember>>(
  (ref) => ref.watch(equipoRepositoryProvider).list(),
);

final tecnicosProvider = FutureProvider.autoDispose<List<TeamMember>>(
  (ref) => ref.watch(equipoRepositoryProvider).tecnicos(),
);

/// Quién está usando la app: de aquí sale si ve la caja o solo su agenda.
final miUsuarioProvider = FutureProvider<({String id, String rol})?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final id = await repo.currentUserId();
  final rol = await repo.currentRole();
  if (id == null || rol == null) return null;
  return (id: id, rol: rol);
});

/// El dueño ve todo; el técnico solo su agenda y sus servicios.
final soyDuenoProvider = Provider<bool>((ref) {
  final yo = ref.watch(miUsuarioProvider).valueOrNull;
  // Mientras carga se asume técnico: es lo más restrictivo, y así la caja no alcanza a
  // parpadear en la pantalla de alguien que no debe verla.
  return yo != null && (yo.rol == 'owner' || yo.rol == 'admin');
});

// ── Servicios ────────────────────────────────────────────────
final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(
    ref.watch(databaseProvider),
    ref.watch(authRepositoryProvider).currentTenantId,
  ),
);

/// La agenda de hoy.
///
/// El dueño ve TODAS las visitas del día; el técnico solo las suyas. Así no tiene que
/// buscar las propias entre las de sus compañeros mientras maneja.
final agendaHoyProvider = FutureProvider.autoDispose<List<ServiceJob>>((ref) async {
  final yo = await ref.watch(miUsuarioProvider.future);
  final esDueno = yo != null && (yo.rol == 'owner' || yo.rol == 'admin');
  return ref.watch(servicesRepositoryProvider).agendaDe(
        DateTime.now(),
        soloDelTecnico: esDueno ? null : yo?.id,
      );
});

/// ¿A quién le toca? — la pantalla estrella.
final pendientesProvider = FutureProvider.autoDispose<List<Pendiente>>(
  (ref) => ref.watch(servicesRepositoryProvider).pendientes(),
);

/// Lo que ya está agendado, para el panorama completo debajo de "¿a quién le toca?".
final agendadosProvider =
    FutureProvider.autoDispose<List<({ServiceJob visita, Client cliente})>>(
  (ref) => ref.watch(servicesRepositoryProvider).agendados(),
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
