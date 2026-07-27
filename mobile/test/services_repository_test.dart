import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agua_segura_mobile/data/local/database.dart';
import 'package:agua_segura_mobile/features/clients/clients_repository.dart';
import 'package:agua_segura_mobile/features/services/services_repository.dart';

void main() {
  late AppDatabase db;
  late ClientsRepository clientes;
  late ServicesRepository servicios;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clientes = ClientsRepository(db, () async => 'empresa-1');
    servicios = ServicesRepository(db, () async => 'empresa-1');
  });

  tearDown(() => db.close());

  group('cuándo toca el siguiente', () {
    test('el tinaco se repite a los 6 meses', () {
      expect(siguienteFecha('tinacos', DateTime(2026, 1, 15)), DateTime(2026, 7, 15));
    });

    test('cruza el fin de año', () {
      expect(siguienteFecha('tinacos', DateTime(2026, 10, 20)), DateTime(2027, 4, 20));
    });

    test('no inventa un día que no existe', () {
      // 31 de agosto + 6 meses = 28 de febrero, no un "31 de febrero".
      expect(siguienteFecha('tinacos', DateTime(2026, 8, 31)), DateTime(2027, 2, 28));
    });

    test('respeta el año bisiesto', () {
      expect(siguienteFecha('tinacos', DateTime(2027, 8, 31)), DateTime(2028, 2, 29));
    });

    test('la plomería no se reprograma sola', () {
      expect(siguienteFecha('plomeria', DateTime(2026, 1, 15)), isNull);
    });
  });

  group('¿a quién le toca?', () {
    test('al terminar, la próxima fecha se anota sola', () async {
      final cliente = await clientes.add(name: 'Sra. Martínez');
      final visita = await servicios.agendar(
        clientId: cliente.id,
        serviceType: 'tinacos',
      );

      await servicios.completar(
        visita,
        priceCents: 70000,
        isPaid: true,
        performedOn: DateTime(2026, 1, 15),
      );

      final guardado = (await servicios.list()).single;
      expect(guardado.status, 'realizado');
      expect(guardado.nextDueOn, '2026-07-15');
      // Debe quedar en la cola para subir al servidor cuando haya señal.
      expect(guardado.isDirty, isTrue);
    });

    test('aparece quien ya se pasó de la fecha', () async {
      final cliente = await clientes.add(name: 'Sra. Martínez');
      final visita = await servicios.agendar(clientId: cliente.id, serviceType: 'tinacos');
      // Hace un año: se pasó por mucho de los seis meses.
      await servicios.completar(
        visita,
        priceCents: 70000,
        isPaid: true,
        performedOn: DateTime.now().subtract(const Duration(days: 365)),
      );

      final lista = await servicios.pendientes();
      expect(lista.single.cliente.name, 'Sra. Martínez');
      expect(lista.single.vencido, isTrue);
      expect(lista.single.diasVencido, greaterThan(0));
    });

    test('no aparece quien todavía no le toca', () async {
      final cliente = await clientes.add(name: 'Sr. Ramírez');
      final visita = await servicios.agendar(clientId: cliente.id, serviceType: 'tinacos');
      // Ayer: le toca hasta dentro de seis meses.
      await servicios.completar(
        visita,
        priceCents: 70000,
        isPaid: true,
        performedOn: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(await servicios.pendientes(), isEmpty);
    });

    test('no se le recuerda a quien ya tiene visita agendada', () async {
      final cliente = await clientes.add(name: 'Depto. Las Flores');
      final visita = await servicios.agendar(clientId: cliente.id, serviceType: 'tinacos');
      await servicios.completar(
        visita,
        priceCents: 70000,
        isPaid: true,
        performedOn: DateTime.now().subtract(const Duration(days: 365)),
      );
      expect(await servicios.pendientes(), hasLength(1));

      // Ya le agendaron: no tiene caso recordarle.
      await servicios.agendar(clientId: cliente.id, serviceType: 'tinacos');
      expect(await servicios.pendientes(), isEmpty);
    });

    test('lo más vencido va primero', () async {
      Future<void> servicioHace(String nombre, int dias) async {
        final c = await clientes.add(name: nombre);
        final v = await servicios.agendar(clientId: c.id, serviceType: 'tinacos');
        await servicios.completar(
          v,
          priceCents: 70000,
          isPaid: true,
          performedOn: DateTime.now().subtract(Duration(days: dias)),
        );
      }

      await servicioHace('Menos urgente', 190);
      await servicioHace('Más urgente', 500);

      final lista = await servicios.pendientes();
      expect(lista.map((p) => p.cliente.name), ['Más urgente', 'Menos urgente']);
    });
  });

  group('corte de caja', () {
    test('separa lo cobrado de lo que quedó a deber', () async {
      final hoy = DateTime.now();
      final a = await clientes.add(name: 'Pagó');
      final b = await clientes.add(name: 'Quedó a deber');

      final v1 = await servicios.agendar(clientId: a.id, serviceType: 'tinacos');
      await servicios.completar(v1, priceCents: 70000, isPaid: true, performedOn: hoy);
      final v2 = await servicios.agendar(clientId: b.id, serviceType: 'techos');
      await servicios.completar(v2, priceCents: 120000, isPaid: false, performedOn: hoy);

      final corte = await servicios.corte(hoy, hoy);
      expect(corte.cobrado, 70000);
      expect(corte.porCobrar, 120000);
      expect(corte.visitas, 2);
    });
  });

  group('clientes', () {
    test('el borrado deja rastro para que el servidor se entere', () async {
      final c = await clientes.add(name: 'Sra. Martínez');
      await clientes.remove(c);

      expect(await clientes.list(), isEmpty);
      final fila = await db.clientById(c.id);
      expect(fila!.isDeleted, isTrue);
      expect(fila.isDirty, isTrue);
    });
  });

  group('recomendaciones', () {
    test('quien más recomienda va primero', () async {
      final estrella = await clientes.add(name: 'Sra. Martínez');
      final otro = await clientes.add(name: 'Sr. Ramírez');
      await clientes.add(name: 'Vecina 1', referredById: estrella.id);
      await clientes.add(name: 'Vecina 2', referredById: estrella.id);
      await clientes.add(name: 'Compadre', referredById: otro.id);

      final lista = await clientes.recomendadores();
      expect(lista.map((r) => r.cliente.name), ['Sra. Martínez', 'Sr. Ramírez']);
      expect(lista.first.recomendados, 2);
    });

    test('quien no ha recomendado a nadie no aparece', () async {
      await clientes.add(name: 'Nadie lo mandó');
      expect(await clientes.recomendadores(), isEmpty);
    });
  });

  group('certificado', () {
    test('cada servicio tiene su propia frase de respaldo', () {
      // Si mañana se agrega un servicio y se olvida su frase, el certificado saldría
      // con un texto genérico. Esta prueba lo caza antes de que le llegue a un cliente.
      for (final tipo in tiposDeServicio.keys) {
        expect(
          protocoloCertificado[tipo],
          isNotNull,
          reason: 'falta la frase del certificado para "$tipo"',
        );
      }
    });

    test('la frase de respaldo nombra el trabajo que se hizo', () {
      expect(protocoloCertificado['impermeabilizacion'], contains('impermeabilización'));
      expect(protocoloCertificado['tinacos'], contains('desinfección'));
      // Y nunca al revés: sería una plantilla mal copiada.
      expect(protocoloCertificado['impermeabilizacion'], isNot(contains('desinfección')));
    });

    test('la firma es la misma para todos', () {
      expect(firmaCertificado, contains('seguridad de su familia y patrimonio'));
    });
  });
}
