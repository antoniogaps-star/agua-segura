import 'package:flutter/material.dart';

import 'activation_screen.dart';
import 'admin_keys_screen.dart';

/// Un plan comercial con sus precios (en pesos) y beneficios.
class _Plan {
  const _Plan({
    required this.name,
    required this.tagline,
    required this.businesses,
    required this.monthlyNormal,
    required this.monthlyLaunch,
    required this.annual,
    required this.perpetual,
    required this.color,
    required this.features,
    this.featured = false,
  });

  final String name;
  final String tagline;
  final String businesses;
  final int monthlyNormal;
  final int monthlyLaunch;
  final int annual;
  final int perpetual;
  final Color color;
  final List<String> features;
  final bool featured;
}

const _plans = <_Plan>[
  _Plan(
    name: 'Esencial',
    tagline: 'Para 1 negocio',
    businesses: '1 negocio',
    monthlyNormal: 299,
    monthlyLaunch: 199,
    annual: 2990,
    perpetual: 5990,
    color: Color(0xFF15803D),
    features: [
      'Inventario por voz desde el celular',
      'Registro de productos y existencias',
      'Consulta de inventario',
      'Exportación a Excel',
      'Historial de movimientos',
      'Soporte básico',
    ],
  ),
  _Plan(
    name: 'Profesional',
    tagline: 'Para 2 a 3 negocios',
    businesses: 'hasta 3 negocios',
    monthlyNormal: 599,
    monthlyLaunch: 399,
    annual: 5990,
    perpetual: 10990,
    color: Color(0xFF2F6DF6),
    featured: true,
    features: [
      'Todo lo del plan Esencial',
      'Administración de hasta 3 negocios',
      'Cada negocio con su propia cartera de clientes',
      'Reportes de inventario descargables',
      'Control de entradas y salidas',
      'Usuarios y permisos',
      'Soporte prioritario',
    ],
  ),
  _Plan(
    name: 'Empresarial',
    tagline: 'Hasta 6 negocios',
    businesses: 'hasta 6 negocios',
    monthlyNormal: 999,
    monthlyLaunch: 699,
    annual: 9990,
    perpetual: 17990,
    color: Color(0xFF7C3AED),
    features: [
      'Todo lo del plan Profesional',
      'Administración de hasta 6 negocios',
      'Panel de control general',
      'Reportes avanzados y comparación entre negocios',
      'Control centralizado de inventarios',
      'Más usuarios',
      'Acceso a nuevas funciones',
    ],
  ),
];

String _money(int pesos) {
  final s = pesos.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '\$$buf';
}

/// Pantalla de Planes y Precios. Se puede abrir desde el login (para enseñarla) y
/// más adelante se mostrará automáticamente al terminar la prueba gratis.
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planes y precios')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'Deja de escribir producto por producto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Haz tu inventario hablando. Más rápido, más simple, menos errores.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Row(
              children: [
                Text('🚀', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Oferta de lanzamiento: precio especial para los primeros 100 clientes.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final plan in _plans) _PlanCard(plan: plan),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎁 Prueba gratis 7 días',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Sin contratos forzosos. Pruébala sin compromiso.'),
                  SizedBox(height: 12),
                  Text('💳 Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Por transferencia o en efectivo. Al pagar, recibes tu clave de '
                      'activación para desbloquear la app.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ActivationScreen()),
            ),
            icon: const Icon(Icons.vpn_key),
            label: const Text('Ya pagué · Ingresar clave de activación'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminKeysScreen()),
            ),
            icon: const Icon(Icons.admin_panel_settings, size: 18),
            label: const Text('Soy el vendedor · Generar claves'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: plan.featured ? plan.color : Colors.grey.shade300,
          width: plan.featured ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: plan.color,
                  ),
                ),
                const SizedBox(width: 8),
                if (plan.featured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: plan.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('⭐ MÁS ELEGIDO',
                        style: TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            Text(plan.tagline, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(plan.monthlyLaunch),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: plan.color,
                  ),
                ),
                const Text(' /mes', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _money(plan.monthlyNormal),
                    style: const TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Anual ${_money(plan.annual)}  ·  Licencia perpetua ${_money(plan.perpetual)} '
              '(incluye 12 meses de actualizaciones)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 20),
            for (final f in plan.features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: plan.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
