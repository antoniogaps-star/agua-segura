import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import '../../core/secure_store.dart';

part 'database.g.dart';

/// Columnas de sincronización comunes: tombstone, versión, timestamp y el flag local
/// isDirty (cola outbox).
mixin _SyncColumns on Table {
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
}

/// Cliente: una casa, un edificio, un local. Se sincroniza con last-write-wins.
class Clients extends Table with _SyncColumns {
  TextColumn get id => text()(); // UUIDv7 generado en el celular
  TextColumn get tenantId => text()();
  TextColumn get name => text()();

  /// El WhatsApp: por aquí sale el recordatorio y el certificado.
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();

  /// Cómo llegar: "portón verde, junto a la tienda", "tocar en el 3B".
  /// El técnico las usa más que la dirección formal.
  TextColumn get directions => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// El id del cliente que lo recomendó. Los clientes llegan por recomendación, así que
  /// esto dice a quién agradecerle — y a quién volver a pedirle.
  TextColumn get referredById => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// El equipo: el dueño y sus técnicos.
///
/// Solo BAJA del servidor (las altas se hacen contra la API, que fija la contraseña).
/// Se guarda aquí para que la agenda pueda decir "le toca a Luis" en una azotea sin
/// señal, que es justo donde el técnico la va a leer.
class TeamMembers extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  TextColumn get role => text()(); // 'owner' | 'admin' | 'operator' | 'viewer'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Visita de servicio: agendada o ya realizada. Es una sola ficha con estado, porque en
/// la vida real la visita agendada *se convierte* en el servicio realizado.
class ServiceJobs extends Table with _SyncColumns {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get clientId => text()();

  /// 'tinacos' | 'techos' | 'plomeria' | 'impermeabilizacion' | 'calentadores'
  TextColumn get serviceType => text()();

  /// 'agendado' | 'realizado' | 'cancelado'
  TextColumn get status => text().withDefault(const Constant('agendado'))();

  DateTimeColumn get scheduledFor => dateTime().nullable()();
  TextColumn get performedOn => text().nullable()(); // 'YYYY-MM-DD'
  TextColumn get technicianId => text().nullable()();

  IntColumn get priceCents => integer().withDefault(const Constant(0))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();

  /// Cuándo toca el siguiente. Es lo que alimenta "¿a quién le toca?".
  TextColumn get nextDueOn => text().nullable()(); // 'YYYY-MM-DD'

  /// Rutas de las fotos EN EL CELULAR. No viajan al servidor: pesan mucho y su valor
  /// está en el momento de armar el certificado, que también se hace aquí.
  TextColumn get photoBefore => text().nullable()();
  TextColumn get photoAfter => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Clients, ServiceJobs, TeamMembers])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? NativeDatabase.memory());
  AppDatabase.encrypted(SecureStore store) : super(_openEncrypted(store));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());

  // ── Clientes ───────────────────────────────────────────────
  Future<List<Client>> activeClients() => (select(clients)
        ..where((c) => c.isDeleted.equals(false))
        ..orderBy([(c) => OrderingTerm(expression: c.name)]))
      .get();

  Future<Client?> clientById(String id) =>
      (select(clients)..where((c) => c.id.equals(id))).getSingleOrNull();

  // ── Equipo ─────────────────────────────────────────────────
  Future<List<TeamMember>> activeTeam() => (select(teamMembers)
        ..where((t) => t.isDeleted.equals(false) & t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm(expression: t.name)]))
      .get();

  /// Solo los técnicos, que son a quienes se les asignan las visitas.
  Future<List<TeamMember>> technicians() async =>
      (await activeTeam()).where((t) => t.role == 'operator').toList();

  // ── Servicios ──────────────────────────────────────────────
  Future<List<ServiceJob>> activeJobs() => (select(serviceJobs)
        ..where((j) => j.isDeleted.equals(false))
        ..orderBy([
          (j) => OrderingTerm(expression: j.scheduledFor),
          (j) => OrderingTerm(expression: j.performedOn, mode: OrderingMode.desc),
        ]))
      .get();

  /// Los servicios de un cliente, del más reciente al más viejo.
  Future<List<ServiceJob>> jobsOfClient(String clientId) => (select(serviceJobs)
        ..where((j) => j.clientId.equals(clientId) & j.isDeleted.equals(false))
        ..orderBy([(j) => OrderingTerm(expression: j.performedOn, mode: OrderingMode.desc)]))
      .get();

  // ── Cola outbox (pendientes de subir) ──────────────────────
  Future<List<Client>> dirtyClients() =>
      (select(clients)..where((c) => c.isDirty.equals(true))).get();
  Future<List<ServiceJob>> dirtyJobs() =>
      (select(serviceJobs)..where((j) => j.isDirty.equals(true))).get();

  Future<void> markClientSynced(String id) =>
      (update(clients)..where((c) => c.id.equals(id)))
          .write(const ClientsCompanion(isDirty: Value(false)));
  Future<void> markJobSynced(String id) =>
      (update(serviceJobs)..where((j) => j.id.equals(id)))
          .write(const ServiceJobsCompanion(isDirty: Value(false)));
}

/// Abre la base local CIFRADA con SQLCipher. La llave se aplica con `PRAGMA key`
/// antes de cualquier otra sentencia, en el isolate de background.
QueryExecutor _openEncrypted(SecureStore store) {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    }

    final key = await store.databaseKey();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/aguasegura.sqlite');

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        if (Platform.isAndroid) {
          open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
        }
      },
      setup: (db) {
        final cipher = db.select('PRAGMA cipher_version;');
        if (cipher.isEmpty) {
          throw StateError('SQLCipher no disponible: la base no quedaría cifrada');
        }
        final escaped = key.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped';");
      },
    );
  });
}
