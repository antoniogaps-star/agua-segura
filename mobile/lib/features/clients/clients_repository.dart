import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';

/// Clientes sobre la base LOCAL (offline-first). Cada alta se guarda isDirty=true y se
/// sube después con SyncService (entidad 'client', last-write-wins).
class ClientsRepository {
  ClientsRepository(this._db, this._getTenantId);

  final AppDatabase _db;
  final Future<String> Function() _getTenantId;
  static const _uuid = Uuid();

  Future<List<Client>> list() => _db.activeClients();

  Future<Client> add({
    required String name,
    String? phone,
    String? address,
    String? directions,
    String? notes,
  }) async {
    final tenantId = await _getTenantId();
    final id = _uuid.v7();
    await _db.into(_db.clients).insert(
          ClientsCompanion.insert(
            id: id,
            tenantId: tenantId,
            name: name,
            phone: Value(phone),
            address: Value(address),
            directions: Value(directions),
            notes: Value(notes),
          ),
        );
    return (await _db.clientById(id))!;
  }

  /// Corrige la ficha. Sube la versión y marca isDirty para que se vuelva a sincronizar.
  Future<void> update(
    Client c, {
    required String name,
    String? phone,
    String? address,
    String? directions,
    String? notes,
  }) async {
    await (_db.update(_db.clients)..where((t) => t.id.equals(c.id))).write(
      ClientsCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        directions: Value(directions),
        notes: Value(notes),
        version: Value(c.version + 1),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Borrado suave (tombstone): el servidor y los demás celulares necesitan enterarse
  /// de que se borró, cosa que un DELETE local no les contaría.
  Future<void> remove(Client c) async {
    await (_db.update(_db.clients)..where((t) => t.id.equals(c.id))).write(
      ClientsCompanion(
        isDeleted: const Value(true),
        version: Value(c.version + 1),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }
}
