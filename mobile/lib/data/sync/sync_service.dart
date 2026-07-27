import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local/database.dart';

/// El servidor rechazó la subida (HTTP 402) porque la prueba gratis o el plan venció.
/// Los cambios locales quedan intactos y se subirán al reactivar. La UI la distingue de
/// un fallo de red para mostrar "renueva tu plan" en vez de "sin conexión".
class SubscriptionExpiredException implements Exception {
  const SubscriptionExpiredException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Motor de sincronización (patrón outbox): sube los cambios locales pendientes de
/// clientes y servicios, y aplica los del servidor.
///
/// Esto es lo que hace que el técnico pueda trabajar en una azotea sin señal: todo se
/// guarda aquí y sube solo cuando vuelve a haber internet.
class SyncService {
  SyncService(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  Future<void> push() async {
    final clientes = await _db.dirtyClients();
    final trabajos = await _db.dirtyJobs();

    final changes = <Map<String, dynamic>>[
      for (final c in clientes)
        {
          'entity': 'client',
          'id': c.id,
          'op': c.isDeleted ? 'delete' : 'upsert',
          'version': c.version,
          'updated_at': c.updatedAt.toUtc().toIso8601String(),
          'data': {
            'name': c.name,
            'phone': c.phone,
            'address': c.address,
            'directions': c.directions,
            'notes': c.notes,
            'referred_by_id': c.referredById,
          },
        },
      for (final j in trabajos)
        {
          'entity': 'service_job',
          'id': j.id,
          'op': j.isDeleted ? 'delete' : 'upsert',
          'version': j.version,
          'updated_at': j.updatedAt.toUtc().toIso8601String(),
          // Las fotos NO van: se quedan en el celular. Pesan mucho y el certificado se
          // arma aquí mismo.
          'data': {
            'client_id': j.clientId,
            'service_type': j.serviceType,
            'status': j.status,
            'scheduled_for': j.scheduledFor?.toUtc().toIso8601String(),
            'performed_on': j.performedOn,
            'technician_id': j.technicianId,
            'price_cents': j.priceCents,
            'is_paid': j.isPaid,
            'notes': j.notes,
            'next_due_on': j.nextDueOn,
          },
        },
    ];

    if (changes.isEmpty) return;

    // El cliente va ANTES que su servicio: el servidor rechaza un servicio cuyo cliente
    // todavía no conoce. Como los clientes se recorren primero, el orden ya es correcto.
    final Response<dynamic> response;
    try {
      response = await _dio.post('/sync/push', data: {'changes': changes});
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['error'] is Map ? data['error']['message'] as String? : null)
            : null;
        throw SubscriptionExpiredException(
          msg ?? 'Tu prueba o plan venció. Renueva para volver a sincronizar.',
        );
      }
      rethrow;
    }
    final results = (response.data['results'] as List).cast<Map<String, dynamic>>();

    for (final r in results) {
      if (r['status'] != 'applied') continue;
      final id = r['id'] as String;
      switch (r['entity']) {
        case 'client':
          await _db.markClientSynced(id);
        case 'service_job':
          await _db.markJobSynced(id);
      }
    }
  }

  Future<void> pull() async {
    final response = await _dio.get('/sync/pull');
    final changes = (response.data['changes'] as List).cast<Map<String, dynamic>>();
    for (final change in changes) {
      await _applyRemote(change);
    }
  }

  Future<void> _applyRemote(Map<String, dynamic> change) async {
    final id = change['id'] as String;
    final data = (change['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final tenantId = change['tenant_id'] as String? ?? '';
    final deleted = change['op'] == 'delete';

    switch (change['entity']) {
      case 'client':
        await _db.into(_db.clients).insertOnConflictUpdate(
              ClientsCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: data['name'] as String? ?? '',
                phone: Value(data['phone'] as String?),
                address: Value(data['address'] as String?),
                directions: Value(data['directions'] as String?),
                notes: Value(data['notes'] as String?),
                referredById: Value(data['referred_by_id'] as String?),
                isDeleted: Value(deleted),
                isDirty: const Value(false),
              ),
            );
      case 'service_job':
        // Las fotos viven solo aquí: si el servidor pisara la fila sin ellas, el técnico
        // perdería el antes y el después que acaba de tomar. Se conservan a mano.
        final previo = await (_db.select(_db.serviceJobs)
              ..where((j) => j.id.equals(id)))
            .getSingleOrNull();
        await _db.into(_db.serviceJobs).insertOnConflictUpdate(
              ServiceJobsCompanion.insert(
                id: id,
                tenantId: tenantId,
                clientId: data['client_id'] as String? ?? '',
                serviceType: data['service_type'] as String? ?? 'tinacos',
                status: Value(data['status'] as String? ?? 'agendado'),
                scheduledFor: Value(
                  data['scheduled_for'] == null
                      ? null
                      : DateTime.parse(data['scheduled_for'] as String).toLocal(),
                ),
                performedOn: Value(data['performed_on'] as String?),
                technicianId: Value(data['technician_id'] as String?),
                priceCents: Value(data['price_cents'] as int? ?? 0),
                isPaid: Value(data['is_paid'] as bool? ?? false),
                notes: Value(data['notes'] as String?),
                nextDueOn: Value(data['next_due_on'] as String?),
                photoBefore: Value(previo?.photoBefore),
                photoAfter: Value(previo?.photoAfter),
                isDeleted: Value(deleted),
                isDirty: const Value(false),
              ),
            );
    }
  }
}
