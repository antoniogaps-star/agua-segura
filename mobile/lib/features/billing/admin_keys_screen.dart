import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'billing_api.dart';

const _planLabels = {
  'pyme': 'Esencial (1 negocio)',
  'business': 'Profesional (hasta 3)',
  'enterprise': 'Empresarial (hasta 6)',
};

const _monthsLabels = {
  1: '1 mes',
  12: 'Anual (12 meses)',
  0: 'Perpetua (pago único)',
};

/// Pantalla SOLO para el vendedor (Toño): genera claves de activación para
/// compartir a los clientes que pagan. Requiere el secreto de administrador.
class AdminKeysScreen extends ConsumerStatefulWidget {
  const AdminKeysScreen({super.key});

  @override
  ConsumerState<AdminKeysScreen> createState() => _AdminKeysScreenState();
}

class _AdminKeysScreenState extends ConsumerState<AdminKeysScreen> {
  final _secret = TextEditingController();
  String _plan = 'business';
  int _months = 1;
  int _count = 1;
  bool _loading = false;
  String? _error;
  List<String> _codes = [];

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _generar() async {
    if (_secret.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu secreto de administrador.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _codes = [];
    });
    try {
      final codes = await ref.read(billingApiProvider).generateKeys(
            adminSecret: _secret.text.trim(),
            plan: _plan,
            months: _months,
            count: _count,
          );
      if (mounted) setState(() => _codes = codes);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudieron generar. Revisa tu secreto de '
            'administrador (LICENSE_ADMIN_SECRET en el servidor).');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _compartir(String code) {
    final plan = _planLabels[_plan] ?? _plan;
    final msg = 'Tu clave de activación de Agua Segura:\n\n'
        '$code\n\n'
        'Plan: $plan\n'
        'Ábrela en la app → "Activar mi plan" → pega la clave.\n'
        'Descarga la app: https://github.com/antoniogaps-star/agora-erp/releases';
    Share.share(msg, subject: 'Clave de activación · Agua Segura');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generar claves (vendedor)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _secret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Secreto de administrador',
                helperText: 'El que pusiste en LICENSE_ADMIN_SECRET en el servidor.',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'Plan'),
              items: _planLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _plan = v ?? 'business'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _months,
              decoration: const InputDecoration(labelText: 'Vigencia'),
              items: _monthsLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _months = v ?? 1),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _count,
              decoration: const InputDecoration(labelText: 'Cuántas claves'),
              items: const [1, 2, 3, 5, 10]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (v) => setState(() => _count = v ?? 1),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _generar,
              icon: const Icon(Icons.vpn_key),
              label: Text(_loading ? 'Generando…' : 'Generar claves'),
            ),
            const SizedBox(height: 16),
            for (final code in _codes)
              Card(
                child: ListTile(
                  title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_planLabels[_plan] ?? _plan),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copiar',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Clave copiada')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Compartir',
                        onPressed: () => _compartir(code),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
