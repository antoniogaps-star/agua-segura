import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';

/// Los cinco servicios del negocio, con su nombre bonito para la pantalla.
const tiposDeServicio = <String, String>{
  'tinacos': 'Lavado y desinfección de tinacos',
  'techos': 'Mantenimiento de techos',
  'plomeria': 'Plomería',
  'impermeabilizacion': 'Impermeabilización',
  'calentadores': 'Calentadores solares',
};

/// Cada cuántos MESES toca repetir. La plomería no aparece porque es correctiva: nadie
/// llama para que le arreglen una fuga que no tiene.
const periodicidadMeses = <String, int>{
  'tinacos': 6,
  'techos': 12,
  'calentadores': 12,
  'impermeabilizacion': 24,
};

/// Precio sugerido en centavos, para no teclearlo cada vez. Es solo una propuesta.
const precioSugeridoCents = <String, int>{'tinacos': 70000}; // $700.00 MXN

/// La línea de respaldo del certificado: **cambia según el trabajo que se hizo**.
///
/// No puede ser una sola para todo: un certificado de impermeabilización que diga
/// "protocolo de lavado y desinfección" se lee como plantilla mal copiada, y este
/// documento existe justamente para dar seriedad — hay clientes que lo guardan como
/// comprobante sanitario.
const protocoloCertificado = <String, String>{
  'tinacos': 'Servicio realizado conforme a nuestro protocolo de lavado y desinfección.',
  'techos': 'Servicio realizado conforme a nuestro protocolo de mantenimiento de techos.',
  'plomeria': 'Servicio realizado conforme a nuestro protocolo de instalación y '
      'reparación hidráulica.',
  'impermeabilizacion':
      'Servicio realizado conforme a nuestro protocolo de impermeabilización.',
  'calentadores':
      'Servicio realizado conforme a nuestro protocolo de mantenimiento de '
          'calentadores solares.',
};

/// La firma del certificado: **es la misma siempre**, sea cual sea el servicio.
///
/// A propósito habla de "seguridad" y "patrimonio" y no del agua: así cubre los cinco
/// trabajos —el agua limpia es salud, y el techo y la azotea son patrimonio— y la marca
/// dice lo mismo en todos los documentos que salen del negocio.
const firmaCertificado =
    'En Agua Segura cuidamos la seguridad de su familia y patrimonio.';

/// Calcula cuándo toca repetir un servicio. Devuelve null si no es preventivo.
///
/// Se suma en MESES, no en días: seis meses después del 15 de enero es el 15 de julio.
/// Y si el día no existe en el mes destino (31 de agosto + 6 meses), se recorre al
/// último día de ese mes en vez de inventar una fecha imposible.
DateTime? siguienteFecha(String tipo, DateTime desde) {
  final meses = periodicidadMeses[tipo];
  if (meses == null) return null;

  final total = desde.month - 1 + meses;
  final anio = desde.year + total ~/ 12;
  final mes = total % 12 + 1;
  final ultimoDia = DateTime(anio, mes + 1, 0).day;
  return DateTime(anio, mes, desde.day < ultimoDia ? desde.day : ultimoDia);
}

/// Un cliente al que ya le tocó su mantenimiento, o le toca pronto.
class Pendiente {
  const Pendiente({
    required this.cliente,
    required this.tipo,
    required this.ultimoServicio,
    required this.vence,
    required this.diasVencido,
  });

  final Client cliente;
  final String tipo;
  final DateTime ultimoServicio;
  final DateTime vence;

  /// Positivo = ya se pasó · Negativo = todavía faltan días.
  final int diasVencido;

  bool get vencido => diasVencido >= 0;
  bool get estaSemana => diasVencido < 0 && diasVencido >= -7;
}

/// Servicios y el recordatorio de mantenimiento, sobre la base LOCAL.
///
/// El cálculo de "¿a quién le toca?" se hace AQUÍ, en el celular, no en el servidor: es
/// la pantalla que se abre primero y tiene que responder aunque no haya señal.
class ServicesRepository {
  ServicesRepository(this._db, this._getTenantId);

  final AppDatabase _db;
  final Future<String> Function() _getTenantId;
  static const _uuid = Uuid();

  Future<List<ServiceJob>> list() => _db.activeJobs();

  Future<List<ServiceJob>> ofClient(String clientId) => _db.jobsOfClient(clientId);

  /// La agenda de un día: las visitas planeadas para esa fecha.
  ///
  /// Con [soloDelTecnico] se acota a las de una persona: es lo que ve el técnico al
  /// abrir la app, sin la carga de trabajo de los demás encima.
  Future<List<ServiceJob>> agendaDe(DateTime dia, {String? soloDelTecnico}) async {
    final todos = await _db.activeJobs();
    return todos
        .where((j) =>
            j.status == 'agendado' &&
            j.scheduledFor != null &&
            _mismoDia(j.scheduledFor!, dia) &&
            (soloDelTecnico == null || j.technicianId == soloDelTecnico))
        .toList();
  }

  /// Agenda una visita, o **reprograma la que ya había**.
  ///
  /// Un cliente no puede tener dos visitas abiertas del mismo servicio: no existe "ir a
  /// impermeabilizarle la azotea dos veces el martes". Si ya hay una agendada, se le
  /// cambia la fecha en vez de crear otra — antes se duplicaban en la agenda del técnico
  /// y no había cómo distinguir cuál era la buena.
  ///
  /// Devuelve la visita y si [reprogramada] es true, para que la pantalla pueda decir
  /// "se cambió la fecha" en vez de "se agendó".
  Future<({ServiceJob visita, bool reprogramada})> agendar({
    required String clientId,
    required String serviceType,
    DateTime? scheduledFor,
    String? notes,
    int? priceCents,
    String? technicianId,
  }) async {
    final yaAgendada = (await _db.activeJobs()).where(
      (j) =>
          j.clientId == clientId &&
          j.serviceType == serviceType &&
          j.status == 'agendado',
    );

    if (yaAgendada.isNotEmpty) {
      final previa = yaAgendada.first;
      await (_db.update(_db.serviceJobs)..where((j) => j.id.equals(previa.id))).write(
        ServiceJobsCompanion(
          scheduledFor: Value(scheduledFor),
          notes: notes == null ? const Value.absent() : Value(notes),
          priceCents: priceCents == null ? const Value.absent() : Value(priceCents),
          technicianId:
              technicianId == null ? const Value.absent() : Value(technicianId),
          version: Value(previa.version + 1),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );
      final actualizada =
          await (_db.select(_db.serviceJobs)..where((j) => j.id.equals(previa.id)))
              .getSingle();
      return (visita: actualizada, reprogramada: true);
    }

    final tenantId = await _getTenantId();
    final id = _uuid.v7();
    await _db.into(_db.serviceJobs).insert(
          ServiceJobsCompanion.insert(
            id: id,
            tenantId: tenantId,
            clientId: clientId,
            serviceType: serviceType,
            status: const Value('agendado'),
            scheduledFor: Value(scheduledFor),
            notes: Value(notes),
            priceCents: Value(priceCents ?? precioSugeridoCents[serviceType] ?? 0),
            technicianId: Value(technicianId),
          ),
        );
    final nueva =
        await (_db.select(_db.serviceJobs)..where((j) => j.id.equals(id))).getSingle();
    return (visita: nueva, reprogramada: false);
  }

  /// Marca el servicio como realizado y programa el siguiente **solo**.
  ///
  /// Aquí se resuelve el problema que originó la app: nadie tiene que acordarse de la
  /// próxima fecha, queda anotada al terminar el trabajo.
  Future<void> completar(
    ServiceJob job, {
    required int priceCents,
    required bool isPaid,
    DateTime? performedOn,
    String? notes,
    String? photoBefore,
    String? photoAfter,
  }) async {
    final hecho = performedOn ?? DateTime.now();
    final proxima = siguienteFecha(job.serviceType, hecho);

    await (_db.update(_db.serviceJobs)..where((j) => j.id.equals(job.id))).write(
      ServiceJobsCompanion(
        status: const Value('realizado'),
        performedOn: Value(_soloFecha(hecho)),
        priceCents: Value(priceCents),
        isPaid: Value(isPaid),
        notes: notes == null ? const Value.absent() : Value(notes),
        nextDueOn: Value(proxima == null ? null : _soloFecha(proxima)),
        photoBefore: photoBefore == null ? const Value.absent() : Value(photoBefore),
        photoAfter: photoAfter == null ? const Value.absent() : Value(photoAfter),
        version: Value(job.version + 1),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Guarda una foto sin tocar nada más (el técnico la toma antes de empezar).
  Future<void> guardarFoto(ServiceJob job, {String? antes, String? despues}) async {
    await (_db.update(_db.serviceJobs)..where((j) => j.id.equals(job.id))).write(
      ServiceJobsCompanion(
        photoBefore: antes == null ? const Value.absent() : Value(antes),
        photoAfter: despues == null ? const Value.absent() : Value(despues),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Ajusta cuánto se le cobra a un cliente por un servicio **ya realizado**.
  ///
  /// Existe aparte de [completar] porque el cobro se corrige después: el técnico anota
  /// la visita en la azotea y el dueño acomoda el monto en la noche, cuando hace su
  /// corte. No se toca la fecha del próximo mantenimiento.
  Future<void> ajustarCobro(ServiceJob job, {int? priceCents, bool? isPaid}) async {
    await (_db.update(_db.serviceJobs)..where((j) => j.id.equals(job.id))).write(
      ServiceJobsCompanion(
        priceCents: priceCents == null ? const Value.absent() : Value(priceCents),
        isPaid: isPaid == null ? const Value.absent() : Value(isPaid),
        version: Value(job.version + 1),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// **Lo que debe cada cliente**, sumando todos sus servicios sin pagar.
  ///
  /// Se agrupa por cliente y no por servicio porque así es como se cobra en la realidad:
  /// se le habla a la persona, no al trabajo. Si un cliente tiene tres visitas
  /// pendientes, lo que importa es el total que va a entregar.
  Future<List<({Client cliente, int total, List<ServiceJob> servicios})>>
      porCobrarPorCliente() async {
    final clientes = {for (final c in await _db.activeClients()) c.id: c};
    final porCliente = <String, List<ServiceJob>>{};
    for (final j in await _db.activeJobs()) {
      if (j.status != 'realizado' || j.isPaid) continue;
      porCliente.putIfAbsent(j.clientId, () => []).add(j);
    }

    final lista = <({Client cliente, int total, List<ServiceJob> servicios})>[];
    for (final entrada in porCliente.entries) {
      final cliente = clientes[entrada.key];
      if (cliente == null) continue;
      final total = entrada.value.fold<int>(0, (s, j) => s + j.priceCents);
      lista.add((cliente: cliente, total: total, servicios: entrada.value));
    }
    // El que más debe primero: es a quien conviene cobrarle hoy.
    lista.sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }

  /// Los servicios YA cobrados dentro del rango, para el corte del día.
  Future<List<ServiceJob>> cobradosEntre(DateTime desde, DateTime hasta) async {
    final trabajos = await _db.activeJobs();
    return trabajos.where((j) {
      if (j.status != 'realizado' || !j.isPaid || j.performedOn == null) return false;
      final dia = DateTime.parse(j.performedOn!);
      return !dia.isBefore(_diaCero(desde)) && !dia.isAfter(_diaCero(hasta));
    }).toList();
  }

  Future<void> cancelar(ServiceJob job) async {
    await (_db.update(_db.serviceJobs)..where((j) => j.id.equals(job.id))).write(
      ServiceJobsCompanion(
        status: const Value('cancelado'),
        version: Value(job.version + 1),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  // ── ¿A QUIÉN LE TOCA? ────────────────────────────────────
  // La pantalla estrella. Todo lo demás existe para alimentarla.

  /// Clientes con su mantenimiento vencido o por vencer, lo más urgente primero.
  ///
  /// Se toma el ÚLTIMO servicio realizado de cada cliente y tipo (alguien puede tener
  /// tinacos y calentadores con fechas distintas) y se descarta si ya tiene otra visita
  /// agendada: no tiene caso recordarle a quien ya te espera.
  Future<List<Pendiente>> pendientes({int dentroDeDias = 30}) async {
    final clientes = {for (final c in await _db.activeClients()) c.id: c};
    final trabajos = await _db.activeJobs();
    final hoy = DateTime.now();

    // Lo más reciente por cliente+tipo, y qué pares ya tienen visita agendada.
    final ultimos = <String, ServiceJob>{};
    final agendados = <String>{};
    for (final j in trabajos) {
      final llave = '${j.clientId}|${j.serviceType}';
      if (j.status == 'agendado') {
        agendados.add(llave);
        continue;
      }
      if (j.status != 'realizado' || j.nextDueOn == null || j.performedOn == null) continue;
      final previo = ultimos[llave];
      if (previo == null || j.performedOn!.compareTo(previo.performedOn!) > 0) {
        ultimos[llave] = j;
      }
    }

    final resultado = <Pendiente>[];
    for (final entrada in ultimos.entries) {
      if (agendados.contains(entrada.key)) continue;
      final j = entrada.value;
      final cliente = clientes[j.clientId];
      if (cliente == null) continue;

      final vence = DateTime.parse(j.nextDueOn!);
      final dias = _diasEntre(vence, hoy);
      if (dias < -dentroDeDias) continue; // todavía falta mucho

      resultado.add(Pendiente(
        cliente: cliente,
        tipo: j.serviceType,
        ultimoServicio: DateTime.parse(j.performedOn!),
        vence: vence,
        diasVencido: dias,
      ));
    }

    // Lo más vencido primero: es lo que hay que atender hoy.
    resultado.sort((a, b) => b.diasVencido.compareTo(a.diasVencido));
    return resultado;
  }

  /// **Lo que ya está agendado**, de la visita más próxima a la más lejana.
  ///
  /// Va debajo de "¿a quién le toca?" para completar el panorama: aquella lista dice a
  /// quién FALTA llamarle, y esta dice qué ya quedó cerrado y con quién. Sin la segunda,
  /// el dueño no ve de un vistazo cómo viene la semana.
  Future<List<({ServiceJob visita, Client cliente})>> agendados() async {
    final clientes = {for (final c in await _db.activeClients()) c.id: c};
    final lista = <({ServiceJob visita, Client cliente})>[];

    for (final j in await _db.activeJobs()) {
      if (j.status != 'agendado') continue;
      final cliente = clientes[j.clientId];
      if (cliente == null) continue;
      lista.add((visita: j, cliente: cliente));
    }

    lista.sort((a, b) {
      final fa = a.visita.scheduledFor;
      final fb = b.visita.scheduledFor;
      // Las que se quedaron sin fecha van al final: son las que hay que acomodar.
      if (fa == null) return fb == null ? 0 : 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });
    return lista;
  }

  // ── Corte de caja ────────────────────────────────────────

  /// Lo cobrado y lo pendiente de cobro entre dos fechas (inclusive).
  Future<({int cobrado, int porCobrar, int visitas})> corte(
    DateTime desde,
    DateTime hasta,
  ) async {
    final trabajos = await _db.activeJobs();
    var cobrado = 0, porCobrar = 0, visitas = 0;
    for (final j in trabajos) {
      if (j.status != 'realizado' || j.performedOn == null) continue;
      final dia = DateTime.parse(j.performedOn!);
      if (dia.isBefore(_diaCero(desde)) || dia.isAfter(_diaCero(hasta))) continue;
      visitas++;
      if (j.isPaid) {
        cobrado += j.priceCents;
      } else {
        porCobrar += j.priceCents;
      }
    }
    return (cobrado: cobrado, porCobrar: porCobrar, visitas: visitas);
  }
}

String _soloFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _diaCero(DateTime d) => DateTime(d.year, d.month, d.day);

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Días transcurridos desde [vence] hasta [hoy], sin que el horario de verano meta ruido.
int _diasEntre(DateTime vence, DateTime hoy) =>
    _diaCero(hoy).difference(_diaCero(vence)).inDays;
