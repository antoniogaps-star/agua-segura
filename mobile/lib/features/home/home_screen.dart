import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/sync/sync_service.dart';
import '../billing/pricing_screen.dart';
import '../caja/caja_tab.dart';
import '../clients/clients_tab.dart';
import '../pendientes/pendientes_tab.dart';
import '../services/agenda_tab.dart';

/// Shell principal tras iniciar sesión.
///
/// La primera pestaña es **¿A quién le toca?** a propósito: es el problema que originó
/// la app ("se me olvida a quién le toca renovar"), así que es lo primero que se ve al
/// abrirla, sin tener que buscarlo.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  Future<void> _sync() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sync = ref.read(syncServiceProvider);
      await sync.push();
      await sync.pull();
      ref.invalidate(clientsProvider);
      ref.invalidate(agendaHoyProvider);
      ref.invalidate(pendientesProvider);
      ref.invalidate(corteDeHoyProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Sincronización completa')));
    } on SubscriptionExpiredException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Renovar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PricingScreen()),
            ),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sin conexión: se sincronizará luego')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => '¿A quién le toca?',
          1 => 'Agenda de hoy',
          2 => 'Clientes',
          _ => 'Caja',
        }),
        actions: [
          // La pantalla de planes NO va en la barra: esta app es para llevar el
          // control del negocio, no para venderle nada a quien la usa. Sigue
          // accesible desde el aviso que sale si la prueba vence.
          IconButton(icon: const Icon(Icons.sync), tooltip: 'Sincronizar', onPressed: _sync),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [PendientesTab(), AgendaTab(), ClientsTab(), CajaTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            label: 'Les toca',
          ),
          NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Hoy'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientes'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Caja',
          ),
        ],
      ),
    );
  }
}
